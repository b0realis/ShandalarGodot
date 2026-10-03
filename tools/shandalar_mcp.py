#!/usr/bin/env python3
"""The MCP server — Shandalar's tools for a program that speaks the Model
Context Protocol (2026-09-27).

One process on stdio: JSON-RPC 2.0, one message a line, the protocol's
`initialize`, `tools/list`, `tools/call`, `resources/list` and
`resources/read`, and nothing else. Every tool is a thin wrapper over
the one door, `./shandalar.sh` (or a Windows release's console executable;
AGENTS.md is the contract): the door's
verbs run as subprocesses, their JSON comes back as the tool's
`structuredContent`, their refusal envelopes come back as `isError`
results with the envelope intact, and the referee's pipe is kept open
across calls as a *game* the client plays one decision at a time.

    ./shandalar.sh mcp                              the checkout, or a release
    python3 tools/shandalar_mcp.py [--door PATH] [--workspace DIR]

An MCP client is pointed at that command; `tools/list` is the whole
catalogue, each tool with the description and the schema a program
reads before it calls; `initialize` carries a short guide as its
`instructions`. No third-party module: the Python that runs the other
tools runs this one.

THE RULES IT KEEPS:

  * STDOUT IS THE PROTOCOL'S. The referee's stderr goes to a file under
    the workspace, the Lab's progress is switched off (`--quiet`), and
    this process's own notes go to its stderr.
  * A PATH A TOOL WRITES LIES UNDER THE CHECKOUT OR THE WORKSPACE — the
    Lab's `--out`, the AutoDeck's `--out`, a deck `write_deck` makes,
    the referee's `--log`. A client cannot be pointed at /etc. The
    workspace (`--workspace`, default `workspace/` beside the door) is
    where a client's own decks and runs go by default.
  * A DECK IS NAMED THE WAY THE DOOR NAMES IT, PLUS THE WORKSPACE. A
    deck argument (`check_deck`, `lab`, `autodeck`'s `keep`, the
    referee's seats) passes as typed when the door will find it — an
    absolute path, a path under the checkout or under `decks/`; a bare
    name that is a file or folder in the workspace (a deck `write_deck`
    wrote, an AutoDeck field) is handed over as its absolute path; any
    other word (`random`) passes through untouched.
  * A TOOL NEVER INVENTS A RESULT. A door that exits 0 is quoted; a
    door that refuses is quoted, `isError: true` with the envelope as
    the structured content; a door without its engine is quoted (exit
    3). Unknown tool arguments are refused with the spellings meant,
    the way the door refuses a flag.
  * PLAYING IS A SESSION. `referee_start` (or `referee_join`) opens the
    pipe and returns the first decision; `referee_act` answers it and
    returns the next one; a `result` ends the game and the process.
    `referee_host` (2026-10-03) opens a table of its own in the game's
    lobby and answers with the `table` line first — how a person finds
    it — then `referee_wait` reads on until they sit down.
    Nothing is played between calls, so a client may think as long as
    it likes. The decision's `view` is rendered `brief` by default (the
    board, the hand, the new journal lines — a tenth of the wire's
    view); `full` is the referee's own line, `options` the legal
    answers alone.
  * THE DUMB PILOT the referee's tests use (keep, play a land, cast the
    first castable spell, attack with everything, block nothing) is
    `referee_act` with `"default"` and `referee_autoplay` — so a client
    can skip through the decisions it does not care about and still
    reach a `result`.

`tools/test_shandalar_mcp.py` drives this server against a fake door
(no engine) and, when `SHANDALAR_MCP_LIVE=1`, against the real one;
`tests/tools/test_mcp_2026_09_27.gd` runs the live half inside the
gate.
"""

from __future__ import annotations

import argparse
import difflib
import json
import math
import os
import queue
import re
import signal
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path

SERVER_NAME = "shandalar"
PROTOCOL_VERSIONS = ("2024-11-05", "2025-03-26", "2025-06-18")
LATEST_PROTOCOL = PROTOCOL_VERSIONS[-1]
DOOR_NAME = "shandalar.sh"
WINDOWS_DOOR = "Shandalar.console.exe"
CONTRACT = "AGENTS.md"
PLAY_GUIDE = "agentic-playgude-mtg.md"
WORKSPACE = "workspace"
DEFAULT_TIMEOUT = 900
DECISION_TIMEOUT = 120
MANUALS = ("door", "lab", "autodeck", "query", "referee", "convert")
SEATS = ("agent", "apprentice", "magician", "sorcerer", "wizard", "unfair")
VIEWS = ("brief", "full", "options", "delta")
# `referee_act`'s `until`: the stop the server passes priority toward —
# the seat's own main phase, the end step of this turn, the seat's next
# turn, only a reaction window (`respond`), or the next point the seat
# can act at all (`play`). Every value stops at a reaction window: an
# opponent's spell or ability on the stack, their attack and block
# steps, their end step, a non-priority decision (see `stop_reason`).
UNTIL = ("main", "end", "turn", "respond", "play")
ACCESS = ("open", "invitation")
MAX_PASSES = 400
# The most copies one deck line may name: engine/deck_list.gd's MAX_COUNT.
MAX_COUNT = 500
RESULT_LIMIT = 50
# A kept game: the referee listens on a loopback socket and outlives
# this server; the handshake file it writes, the seconds a boot may take,
# the seconds a referee that should already be listening gets to answer.
KEEP_BOOT = 60
KEEP_RESUME = 5
KEEP_IDLE = 1800

INSTRUCTIONS = (
    "Shandalar is a Magic: The Gathering engine with computer players. "
    "Start with `status` (the version, the folders) and `packs` (which card "
    "packs are on). Decks: `list_decks`, `read_deck`, `write_deck` (a list of "
    "'4 Lightning Bolt' lines, checked as it is written), `autodeck` (build a "
    "field of decks from wishes), `check_deck` (is it playable, and why not), "
    "`cards` (a card's record). Measuring: `lab` plays decks against decks "
    "headless and reports win rates with confidence intervals; `read_run` "
    "reads a finished run; `lab_next` runs what a run left open; "
    "`lab_resume` finishes an interrupted one. Playing: `referee_start` opens "
    "one duel (you in a seat against a computer player, or against yourself "
    "in both seats), `referee_act` answers the pending decision with one of "
    "its `options` — add `until` (`main`, `end`, `turn`, `respond`, `play`) "
    "and the server passes priority for you up to the next point a player "
    "would act: your own main phase, a spell or ability of the opponent's on "
    "the stack while you hold an answer, their attack, block and end steps "
    "while you hold an instant or ability, every attack, block and choice of "
    "your own. `view: \"delta\"` shows only what changed since the last decision. "
    "`referee_join` sits at a table a person hosts in the game (an invitation, "
    "an access code, or an open table's name on the LAN); `referee_host` hosts "
    "a table yourself and tells you how the person finds it (the table's name "
    "in their Game Browser, or an invitation to paste); joined and hosted games "
    "are kept by default — they survive this server's restart and "
    "`referee_resume` takes them up again. `contract` is the whole contract page; `manual` a "
    "tool's own help. "
    "Read `play_guide` for MTG rules, fair-information play, combat and deck "
    "building; optionally request one chapter (1-16) instead of the full guide."
)


class ToolError(Exception):
    """A refusal a tool reports as data — the door's envelope, or one
    shaped like it."""

    def __init__(self, envelope: dict):
        super().__init__(envelope.get("message", "refused"))
        self.envelope = envelope


class UnknownTool(LookupError):
    """`tools/call` named a tool the catalogue does not have (2026-10-03:
    its own class, because a KeyError raised INSIDE a handler — a row
    without its key — used to be answered "unknown tool" for a tool that
    is there)."""

    def __init__(self, name: str, near: list[str]):
        super().__init__(name)
        self.name = name
        self.near = near


class UnknownResource(LookupError):
    """`resources/read` named a URI the server does not serve."""


class Cancelled(Exception):
    """The client cancelled the request in flight (`notifications/cancelled`)
    or the server is shutting down: the door's child is killed, a referee
    wait stops reading, and no answer is sent (MCP: a cancelled request is
    not answered)."""


def refusal(tool: str, kind: str, message: str, exit_code: int = 2, **more) -> ToolError:
    body = {"tool": tool, "exit": exit_code, "kind": kind, "message": message}
    body.update(more)
    return ToolError(body)


# --- the deck files, read and written without an engine ----------------

# `4 Card` or the Dojo's `4x Card` — the x touches the count, as in
# engine/deck_list.gd (`4 x Card` is four of a card called "x Card" there).
DECK_LINE = re.compile(r"^\s*(\d+)[xX]?\s+(.+?)\s*$")


def parse_deck(text: str) -> dict:
    """The .deck/.dec reading `engine/deck_list.gd` documents: `#` and
    `//` comments (`// NAME: X` names the deck), `name: X`, `4 Card`,
    `4x Card`, `SB: 3 Card`. Lines that are none of these are `errors`;
    the engine's own reading (the `check_deck` tool) is the judge."""
    name = ""
    main: list[dict] = []
    side: list[dict] = []
    errors: list[str] = []
    # The engine's own reading, rule for rule (2026-10-03): a UTF-8 BOM
    # from a Windows editor is not part of the first line, "// NAME : X"
    # may space its colon, and a bare header is the lower-case `name:`
    # (any other spelling is a line the engine refuses, so it is an error
    # here too).
    for raw in text.lstrip("﻿").splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("//"):
            field, colon, value = line[2:].strip().partition(":")
            if colon and field.strip().lower() == "name":
                name = value.strip()
            continue
        if line.startswith("#"):
            continue
        if line.startswith("name:"):
            name = line[5:].strip()
            continue
        target = main
        if line.upper().startswith("SB:"):
            target = side
            line = line[3:].strip()
        found = DECK_LINE.match(line)
        if not found or int(found.group(1)) < 1:
            errors.append(raw)
            continue
        target.append({"count": int(found.group(1)), "name": found.group(2)})
    return {"name": name, "main": main, "sideboard": side,
            "cards": sum(row["count"] for row in main),
            "sideboard_cards": sum(row["count"] for row in side), "errors": errors}


def deck_rows(cards, tool: str, what: str) -> list[dict]:
    """`cards` as a client writes it: a list of `{count, name}` rows, a
    list of '4 Lightning Bolt' strings, or one string of such lines."""
    if isinstance(cards, str):
        cards = [line for line in cards.splitlines() if line.strip()]
    if not isinstance(cards, list):
        raise refusal(tool, "option", f"`{what}` is a list of rows", flag=what)
    rows = []
    for row in cards:
        if isinstance(row, dict) and "name" in row:
            count = row.get("count", 1)
            if not isinstance(count, int) or isinstance(count, bool):
                raise refusal(tool, "option", f"`{what}`: a count is a whole number", flag=what)
            name = row["name"].strip() if isinstance(row["name"], str) else ""
        elif isinstance(row, str):
            found = DECK_LINE.match(row.strip())
            if not found:
                raise refusal(tool, "option",
                              f"`{what}`: '{row}' is not 'COUNT Card Name'", flag=what)
            count, name = int(found.group(1)), found.group(2)
        else:
            raise refusal(tool, "option", f"`{what}`: a row is 'COUNT Card Name' or {{count, name}}",
                          flag=what)
        if count < 1 or not name or len(name.splitlines()) != 1 or "\0" in name:
            raise refusal(tool, "option", f"`{what}`: '{row}' needs a count and a name", flag=what)
        if count > MAX_COUNT:
            # engine/deck_list.gd refuses the line (DeckList.MAX_COUNT); said
            # here before a file is written that the engine would refuse.
            raise refusal(tool, "option", f"`{what}`: '{row}' — no deck holds more than {MAX_COUNT} cards",
                          flag=what)
        rows.append({"count": count, "name": name})
    return rows


def deck_text(name: str, main: list[dict], side: list[dict]) -> str:
    lines = [f"name: {name}"] if name else []
    lines.extend(f"{row['count']} {row['name']}" for row in main)
    lines.extend(f"SB: {row['count']} {row['name']}" for row in side)
    return "\n".join(lines) + "\n"


# --- the referee's view, made brief --------------------------------------

def brief_card(card: dict, cast: dict | None, rules: bool) -> dict:
    out: dict = {"id": card.get("id", ""), "name": card.get("name", "")}
    if card.get("land"):
        out["land"] = True
    if card.get("creature"):
        out["pt"] = f"{card.get('power', 0)}/{card.get('toughness', 0)}"
    for flag in ("tapped", "sick", "attacking"):
        if card.get(flag):
            out[flag] = True
    for key in ("blocking", "attached", "damage", "counters", "protection"):
        if card.get(key):
            out[key] = card[key]
    if rules and not card.get("land") and card.get("rules"):
        out["rules"] = card["rules"]
    if cast:
        if cast.get("castable"):
            out["castable"] = True
        costs = [a.get("cost") for a in cast.get("abilities", []) if a.get("kind") == "spell"]
        if costs and costs[0]:
            out["cost"] = costs[0]
    return out


def names_of(rows) -> list:
    return [row.get("name", row.get("id", "")) if isinstance(row, dict) else row
            for row in (rows or [])]


def brief_view(view: dict, seat: int) -> dict:
    """The seat's whole LAN view, cut to what a decision needs: whose
    turn, the life totals, both boards, this seat's hand with the costs
    and the castable marks, the stack, the new journal lines, and the
    prompts that are open (announcement, choice, damage, discard)."""
    cast = {c.get("id"): c for c in view.get("presentation", {}).get("cards", []) if isinstance(c, dict)}
    out: dict = {"turn": view.get("turn"), "step": view.get("step"), "active": view.get("active"),
                 "actor": view.get("actor"), "seat": seat}
    players = []
    for player in view.get("players", []):
        row = {"seat": player.get("seat"), "deck": player.get("deck_name", ""),
               "life": player.get("life"), "hand": player.get("hand_count"),
               "library": player.get("library_count"),
               "battlefield": [brief_card(c, cast.get(c.get("id")), True)
                               for c in player.get("battlefield", []) if isinstance(c, dict)]}
        for zone in ("graveyard", "exile", "revealed"):
            if player.get(zone):
                row[zone] = names_of(player[zone])
        if player.get("mana"):
            row["mana"] = player["mana"]
        players.append(row)
    out["players"] = players
    out["hand"] = [brief_card(c, cast.get(c.get("id")), True)
                   for c in view.get("hand", []) if isinstance(c, dict)]
    if view.get("stack"):
        out["stack"] = view["stack"]
    for key in ("announcement", "choice", "damage_request", "information", "specials"):
        if view.get(key):
            out[key] = view[key]
    if view.get("discard_count"):
        out["discard_count"] = view["discard_count"]
    out["journal"] = [e.get("text", "") if isinstance(e, dict) else str(e)
                      for e in view.get("journal", [])]
    if view.get("winner", -1) not in (-1, None):
        out["winner"] = view["winner"]
    return out


def delta_view(before: dict | None, now: dict) -> dict:
    """What changed between two briefs: the clock, each player's life
    and counts when they moved, the cards that came and went on the
    boards and in this seat's hand, the cards whose state changed
    (tapped, damaged, attacking...), the stack, the open prompts and the
    journal. The first decision of a game (no `before`) is the whole
    brief, marked `baseline`."""
    if before is None:
        return {**now, "baseline": True}
    out: dict = {k: now.get(k) for k in ("turn", "step", "active", "actor", "seat")}
    was = {p.get("seat"): p for p in before.get("players", []) if isinstance(p, dict)}
    players = []
    for player in now.get("players", []):
        old = was.get(player.get("seat"), {})
        row: dict = {"seat": player.get("seat")}
        for key in ("life", "hand", "library"):
            if player.get(key) != old.get(key):
                row[key] = player.get(key)
                row[key + "_was"] = old.get(key)
        added, gone, changed = card_changes(old.get("battlefield", []), player.get("battlefield", []))
        if added:
            row["battlefield_added"] = added
        if gone:
            row["battlefield_gone"] = gone
        if changed:
            row["battlefield_changed"] = changed
        for zone in ("graveyard", "exile", "revealed"):
            new_names = zone_additions(old.get(zone, []), player.get(zone, []))
            if new_names:
                row[zone + "_added"] = new_names
        if player.get("mana") != old.get("mana") and (player.get("mana") or old.get("mana")):
            row["mana"] = player.get("mana")
        if len(row) > 1:
            players.append(row)
    if players:
        out["players"] = players
    added, gone, changed = card_changes(before.get("hand", []), now.get("hand", []))
    if added:
        out["hand_added"] = added
    if gone:
        out["hand_gone"] = gone
    if changed:
        out["hand_changed"] = changed
    out["castable"] = [c.get("name") for c in now.get("hand", []) if isinstance(c, dict) and c.get("castable")]
    for key in ("stack", "announcement", "choice", "damage_request", "information", "specials",
                "discard_count", "winner"):
        if now.get(key):
            out[key] = now[key]
    out["journal"] = now.get("journal", [])
    return out


def card_changes(old: list, new: list) -> tuple[list, list, list]:
    """Brief cards that arrived, the names of those that left, and the
    cards whose brief changed — the same id with a different line."""
    old_by = {c.get("id"): c for c in old if isinstance(c, dict)}
    new_by = {c.get("id"): c for c in new if isinstance(c, dict)}
    added = [c for i, c in new_by.items() if i not in old_by]
    gone = [f"{c.get('name')} ({i})" for i, c in old_by.items() if i not in new_by]
    changed = [c for i, c in new_by.items() if i in old_by and old_by[i] != c]
    return added, gone, changed


def zone_additions(old: list, new: list) -> list:
    """Names in `new` beyond their count in `old` (a zone of names)."""
    counts: dict = {}
    for name in old:
        counts[name] = counts.get(name, 0) + 1
    out = []
    for name in new:
        if counts.get(name, 0) > 0:
            counts[name] -= 1
        else:
            out.append(name)
    return out


def render_decision(decision: dict, mode: str, before: dict | None = None,
                    brief: dict | None = None) -> dict:
    """One `decision` line for the client: `full` is the referee's own,
    `options` drops the view, `brief` replaces it, `delta` replaces it
    with what changed since `before` (the last brief shown). `brief` is
    the decision's brief when the caller has already made it."""
    if mode == "full":
        return decision
    out = {k: v for k, v in decision.items() if k != "view"}
    if mode in ("brief", "delta") and brief is None:
        brief = brief_view(decision.get("view", {}), int(decision.get("seat", 0)))
    if mode == "brief":
        out["brief"] = brief
    elif mode == "delta":
        out["delta"] = delta_view(before, brief)
    return out


# --- pass-until: where a player would act ---------------------------------

OWN_MAIN = ("MAIN1", "MAIN2")
# Priority windows in which a player holding an instant or an ability
# acts — on the opponent's turn: once their attackers are declared
# (Lightning Bolt the attacker, Fog), after the blocks, between
# first-strike and regular damage, and at the end step (the last moment
# before their untap). On the seat's own turn: after the blocks (Giant
# Growth the blocked creature) and between the two damage steps. The
# beginning of combat is not on the list — a player who wants to tap a
# creature before attacks are declared passes without `until`.
REACT_STEPS_THEIRS = ("DECLARE_ATTACKERS", "DECLARE_BLOCKERS", "FIRST_STRIKE_DAMAGE", "END")
REACT_STEPS_OWN = ("DECLARE_BLOCKERS", "FIRST_STRIKE_DAMAGE")


def attackers_declared(view: dict) -> bool:
    for player in view.get("players", []):
        for card in player.get("battlefield", []) if isinstance(player, dict) else []:
            if isinstance(card, dict) and card.get("attacking"):
                return True
    return False


def stop_reason(decision: dict, until: str, origin: dict | None) -> str:
    """Why the pass-until loop hands `decision` to the client — "" to
    pass it. `origin` is the decision the loop started from (its turn
    and step tell `end` and `turn` where they are). The reasons a real
    player would never pass over come first and apply to every `until`:
    a decision that is not priority (attack, block, discard, damage,
    choice, opening), a cast in progress, an opponent's spell or ability
    on the stack while the seat can respond, a combat or end-step window
    of the opponent's while the seat holds an instant-speed answer."""
    options = decision.get("options") or {}
    view = decision.get("view") or {}
    seat = int(decision.get("seat", 0))
    mode = str(decision.get("mode") or options.get("mode") or "")
    if mode != "priority":
        return f"decision: {mode}"
    if options.get("announcement") or "pass" not in options:
        return "a cast is in progress"
    step = str(decision.get("step") or view.get("step") or "")
    turn = int(decision.get("turn") or view.get("turn") or 0)
    theirs = view.get("active") is not None and int(view.get("active")) != seat
    respond = bool(options.get("respond"))
    stack = view.get("stack") or []
    if stack and isinstance(stack[-1], dict) and stack[-1].get("controller") != seat and respond:
        return f"the opponent's {stack[-1].get('name', 'spell')} is on the stack and you can respond"
    if respond and ((theirs and step in REACT_STEPS_THEIRS) or (not theirs and step in REACT_STEPS_OWN)) \
            and (step != "DECLARE_ATTACKERS" or attackers_declared(view)):
        return f"{'their' if theirs else 'your'} {step.lower().replace('_', ' ')}: you can respond"
    can_act = (bool((options.get("play") or {}).get("lands")) or bool((options.get("prepare") or {}).get("casts"))
               or respond or bool((options.get("special") or {}).get("specials")))
    own_main = not theirs and step in OWN_MAIN and not stack
    origin_turn = int((origin or {}).get("turn") or 0)
    if until == "main":
        if own_main:
            return "your main phase"
    elif until == "turn":
        if own_main and turn > origin_turn:
            return "your turn"
    elif until == "end":
        if step == "END" and turn == origin_turn:
            return "the end step"
        if turn > origin_turn:
            return "the next turn began"
    elif until == "play":
        if own_main and can_act:
            return "your main phase, with something to play"
    return ""


# --- the dumb pilot -------------------------------------------------------

def castable_now(view: dict, card) -> bool:
    """The referee's live castability of `card` — the view's presentation
    row, false for a card it does not list."""
    for row in view.get("presentation", {}).get("cards", []):
        if row.get("id") == card:
            return bool(row.get("castable", False))
    return False


def default_answer(decision: dict, memory: dict) -> dict:
    """Keep, order to play, attack with everything, block nothing,
    discard from the front, assign damage as asked, first choice; in a
    main phase play a land, then cast the first castable spell once
    (prepare, autopay, submit) — the referee's own tests' pilot.
    `memory` (`paid`, `tried`, `strikes`) is the game's, so a spell
    refused once is not cast again that step, and a decision the
    referee has already refused an answer to gets the quiet answer
    (cancel, pass, no attackers) — the third refusal concedes. A
    payment whose tap put a trigger on the stack is cancelled and the
    spell cast again once the trigger has resolved."""
    options = decision.get("options", {})
    view = decision.get("view", {})
    mode = decision.get("mode")
    seat = decision.get("seat")
    strikes = int(memory.get("strikes", {}).get(int(decision.get("n", -1)), 0))
    if strikes >= 3:
        return {"op": "concede"}
    if strikes:
        if mode == "priority":
            return {"op": "cancel"} if "announcement" in options else {"op": "pass"}
        if mode == "attack":
            return {"op": "attack", "cards": []}
        if mode == "block":
            return {"op": "block", "pairs": []}
        if mode == "choice":
            return {"op": "cancel"}
        if mode == "opening":
            return {"op": "keep"}
    if mode == "opening":
        if "order" in options:
            return {"op": "order", "play": True}
        return {"op": "keep"}
    if mode == "attack":
        return {"op": "attack", "cards": [c["card"] for c in options.get("attack", {}).get("attackable", [])
                                          if isinstance(c, dict) and c.get("card")]}
    if mode == "block":
        return {"op": "block", "pairs": []}
    if mode == "discard":
        want = options.get("discard", {})
        hand = [c["card"] for c in want.get("hand", []) if isinstance(c, dict) and c.get("card")]
        return {"op": "discard", "cards": hand[:int(want.get("count", 0))]}
    if mode == "damage":
        request = options.get("damage", {}).get("request", {})
        left = int(request.get("amount", 0))
        points = []
        targets = request.get("targets", [])
        for i, target in enumerate(targets):
            amount = left if i == len(targets) - 1 else min(left, int(target.get("lethal", left)))
            if amount > 0:
                points.append([target.get("id"), amount])
                left -= amount
        return {"op": "damage", "points": points}
    if mode == "choice":
        return {"op": "choice", "picks": list(range(int(options.get("choice", {}).get("count", 1))))}
    if mode == "priority":
        if "announcement" in options:
            draft = options.get("draft", {})
            key = (seat, draft.get("card"), view.get("turn"))
            if not draft.get("reachable", True):
                return {"op": "cancel"}
            paid = memory.setdefault("paid", set())
            if key not in paid:
                paid.add(key)
                return {"op": "autopay", "excluded": [], "count": 1}
            if view.get("stack") and not castable_now(view, draft.get("card")):
                # The payment's tap put a trigger on the stack (City of
                # Brass, Manabarbs) and the sorcery can no longer be cast
                # over it: cancel, let the trigger resolve, then cast it
                # again from the floating pool — forget the payment and the
                # attempt so the main-phase loop prepares it once more
                # (2026-10-02; the first MCP play-through lost a Balance
                # this way, the test pilot waits the same trigger out).
                paid.discard(key)
                memory.setdefault("tried", set()).discard(
                    (seat, view.get("turn"), view.get("step"), draft.get("card")))
                return {"op": "cancel"}
            targets = []
            for slot in options["announcement"].get("slots", []):
                if len(slot.get("targets", [])) < int(slot.get("min", 0)):
                    return {"op": "cancel"}
                for target in slot.get("targets", [])[:int(slot.get("min", 0))]:
                    targets.append([target.get("id"), slot.get("divided", 0)])
            return {"op": "submit", "targets": targets}
        lands = options.get("play", {}).get("lands", [])
        if lands:
            return {"op": "play", "card": lands[0]["card"]}
        main = (view.get("active") == seat and view.get("step") in ("MAIN1", "MAIN2")
                and not view.get("stack"))
        if main:
            tried = memory.setdefault("tried", set())
            for cast in options.get("prepare", {}).get("casts", []):
                key = (seat, view.get("turn"), view.get("step"), cast.get("card"))
                if cast.get("x") or key in tried:
                    continue
                tried.add(key)
                return {"op": "prepare", "card": cast["card"], "kind": "spell",
                        "index": 0, "x": 0, "mode": 0}
        return {"op": "pass"}
    return {"op": "concede"}


# --- one referee process, kept across calls ------------------------------

class Transport:
    """The referee's line pipe, one of two ways: stdin/stdout of a child
    process, or a loopback socket a kept referee listens on."""

    def send_line(self, text: str) -> None:
        raise NotImplementedError

    def read_lines(self):
        raise NotImplementedError

    def close(self, grace: float) -> None:
        raise NotImplementedError

    @property
    def alive(self) -> bool:
        raise NotImplementedError


class PipeTransport(Transport):
    def __init__(self, proc: subprocess.Popen):
        self.proc = proc

    def send_line(self, text: str) -> None:
        if self.proc.stdin is None:
            raise OSError("no stdin")
        self.proc.stdin.write(text + "\n")
        self.proc.stdin.flush()

    def read_lines(self):
        if self.proc.stdout is not None:
            yield from self.proc.stdout

    @property
    def alive(self) -> bool:
        return self.proc.poll() is None

    def close(self, grace: float) -> None:
        if self.proc.stdin is not None:
            try:
                self.proc.stdin.close()
            except (OSError, ValueError):
                pass
        try:
            self.proc.wait(timeout=grace)
        except subprocess.TimeoutExpired:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait()


class SocketTransport(Transport):
    """A kept referee's socket. The connection is made on the reader's
    thread (`read_lines`), so a boot that takes seconds does not hold
    the tool call: the handshake file names the port and the token, the
    first line sent is the token, and the referee answers with `hello`,
    a `resume` line and the pending decision, if any."""

    def __init__(self, handshake: Path, boot: float):
        self.handshake = handshake
        self.boot = boot
        self.sock: socket.socket | None = None
        self.dead = False
        self.lock = threading.Lock()
        self.queued: list[str] = []
        self.queued_error: dict | None = None

    def send_line(self, text: str) -> None:
        with self.lock:
            if self.sock is None:
                if self.dead:
                    raise OSError("the referee is not listening")
                self.queued.append(text)
                return
            self.sock.sendall((text + "\n").encode("utf-8"))

    def connect(self) -> dict | None:
        """The handshake record once the referee has written it and the
        socket is open, or None (the error went to `queued_error`)."""
        deadline = time.monotonic() + self.boot
        record: dict | None = None
        while time.monotonic() < deadline:
            if self.dead:
                return None
            try:
                record = json.loads(self.handshake.read_text(encoding="utf-8"))
                if isinstance(record, dict) and record.get("port"):
                    break
            except (OSError, ValueError):
                pass
            record = None
            time.sleep(0.2)
        if record is None:
            self.queued_error = {"tool": "referee", "exit": 3, "kind": "keep",
                                 "message": f"the referee did not start listening within {self.boot:.0f} s ({self.handshake})"}
            return None
        last = ""
        while time.monotonic() < deadline:
            if self.dead:
                return None
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            try:
                sock.connect(("127.0.0.1", int(record["port"])))
                sock.sendall((json.dumps({"token": record.get("token", ""), "client": SERVER_NAME}) + "\n").encode("utf-8"))
                sock.settimeout(None)
                with self.lock:
                    # Closed while this thread was still connecting (a stop
                    # or a detach during a slow boot): the connection made
                    # now would seat a client nobody reads — and replace the
                    # one that comes back — so it is let go at once.
                    if self.dead:
                        sock.close()
                        return None
                    self.sock = sock
                    for text in self.queued:
                        sock.sendall((text + "\n").encode("utf-8"))
                    self.queued = []
                return record
            except OSError as exc:
                last = str(exc)
                sock.close()
                time.sleep(0.3)
        self.queued_error = {"tool": "referee", "exit": 3, "kind": "keep",
                             "message": f"the referee at port {record.get('port')} did not take the connection: {last}"}
        return None

    def read_lines(self):
        if self.connect() is None:
            closed = self.dead and self.queued_error is None
            self.dead = True
            if not closed:
                yield json.dumps({"error": self.queued_error})
            return
        assert self.sock is not None
        reader = self.sock.makefile("r", encoding="utf-8", errors="replace")
        try:
            for line in reader:
                yield line
        except OSError:
            pass
        finally:
            self.dead = True

    @property
    def alive(self) -> bool:
        return not self.dead

    def close(self, grace: float) -> None:
        with self.lock:
            self.dead = True
            if self.sock is not None:
                try:
                    self.sock.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass
                self.sock.close()
                self.sock = None


def own_group() -> dict:
    """Popen keywords that give a door child a process group of its own —
    the handle `stop_tree` kills it and everything it started by."""
    if os.name == "nt":
        return {"creationflags": getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)}
    return {"start_new_session": True}


def stop_tree(proc: subprocess.Popen, drain: bool = True) -> None:
    """Kill a door child and its process group (the Lab's worker processes
    with it), reap it, and close its pipes even when something that left
    the group still holds them open. `drain=False` when reader threads own
    the pipes: the child is killed and reaped, and they see the end."""
    if proc.returncode is None and os.name != "nt":
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except OSError:
            pass
    try:
        proc.kill()
    except OSError:
        pass
    if not drain:
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            pass
        return
    try:
        proc.communicate(timeout=10)
    except (subprocess.TimeoutExpired, ValueError, OSError):
        pass
    for pipe in (proc.stdout, proc.stderr):
        try:
            if pipe is not None:
                pipe.close()
        except OSError:
            pass
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        pass


def detached_popen(argv: list[str], cwd: Path, stdout, stderr, env: dict) -> subprocess.Popen:
    """A child that outlives this server: its own session (POSIX) or
    process group and console (Windows), stdin closed."""
    more: dict = {}
    if os.name == "nt":
        more["creationflags"] = (getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
                                 | getattr(subprocess, "DETACHED_PROCESS", 0))
    else:
        more["start_new_session"] = True
    return subprocess.Popen(argv, cwd=str(cwd), stdin=subprocess.DEVNULL, stdout=stdout, stderr=stderr,
                            env=env, **more)


class Game:
    def __init__(self, ident: str, argv: list[str], view: str, cwd: Path, stderr_path: Path,
                 keep: dict | None = None, resume: bool = False, cancelled=None):
        self.ident = ident
        # The server's "is the call in flight cancelled?" — read while a
        # line is waited for, so a cancelled wait stops within a beat.
        self.cancelled = cancelled
        self.argv = argv
        self.view = view
        self.started = time.time()
        self.hello: dict | None = None
        # A hosted table's own line: how a person finds it (the name, the
        # access rule, the invitation), said once before hello.
        self.table: dict | None = None
        self.pending: dict | None = None
        self.result: dict | None = None
        self.error: dict | None = None
        self.decisions = 0
        self.last_decision_n: int | None = None
        self.refusals = 0
        self.memory: dict = {}
        self.lines: queue.Queue = queue.Queue()
        self.closed = False
        self.keep = keep
        self.resumed = resume
        # The brief last shown to the client (the `delta` view's base) and
        # the journal lines of decisions passed over by `until`.
        self.last_brief: dict | None = None
        self.passed_journal: list = []
        stderr_path.parent.mkdir(parents=True, exist_ok=True)
        env = dict(os.environ)
        env["SHANDALAR_NO_BANNER"] = "1"
        env["NO_COLOR"] = "1"
        self.proc: subprocess.Popen | None = None
        if keep is None:
            self.stderr_file = stderr_path.open("w", encoding="utf-8")
            try:
                self.proc = subprocess.Popen(argv, cwd=str(cwd), stdin=subprocess.PIPE,
                                             stdout=subprocess.PIPE, stderr=self.stderr_file,
                                             text=True, bufsize=1, encoding="utf-8", errors="replace", env=env)
            except OSError as exc:
                self.stderr_file.close()
                raise refusal("referee", "run", f"the referee would not start: {exc}", exit_code=3)
            self.transport: Transport = PipeTransport(self.proc)
        else:
            self.stderr_file = stderr_path.open("a", encoding="utf-8")
            if not resume:
                lines_file = Path(keep["lines"]).open("a", encoding="utf-8")
                try:
                    self.proc = detached_popen(argv, cwd, lines_file, self.stderr_file, env)
                except OSError as exc:
                    self.stderr_file.close()
                    raise refusal("referee", "run", f"the referee would not start: {exc}", exit_code=3)
                finally:
                    lines_file.close()
            self.transport = SocketTransport(Path(keep["keep"]), KEEP_RESUME if resume else KEEP_BOOT)
        self.pump = threading.Thread(target=self._pump, daemon=True)
        self.pump.start()

    def _pump(self) -> None:
        try:
            for line in self.transport.read_lines():
                self.lines.put(line)
        finally:
            self.lines.put(None)

    @property
    def running(self) -> bool:
        return self.transport.alive and not self.closed

    @property
    def kept(self) -> bool:
        return self.keep is not None

    def send(self, action: dict) -> None:
        if not self.running:
            raise refusal("referee", "game", f"game {self.ident} is over", game=self.ident)
        try:
            # ASCII on the wire (2026-10-03): an action is JSON either way,
            # and no referee read can then end inside a character.
            self.transport.send_line(json.dumps(action))
            # An answer is in flight now. A timeout must not expose the old
            # decision to wait/autoplay or let the client submit it twice.
            self.pending = None
        except (BrokenPipeError, OSError, ValueError) as exc:
            raise refusal("referee", "game", f"game {self.ident}: the pipe closed ({exc})",
                          game=self.ident)

    def advance(self, timeout: float, render: bool = True, until_table: bool = False) -> dict:
        """Read lines until a decision, a result or an error; the
        refusals on the way are collected. `pending: true` says nothing
        arrived in `timeout` seconds — call `referee_wait` again. With
        `until_table`, a hosted table's `table` line is an answer too:
        the client learns how the table is found before anyone sits."""
        refused: list[dict] = []
        deadline = time.monotonic() + max(0.0, timeout)
        while True:
            if self.cancelled is not None and self.cancelled():
                raise Cancelled(f"game {self.ident}: the wait was cancelled")
            left = deadline - time.monotonic()
            if left <= 0:
                return self._state(refused, pending=True, render=render)
            try:
                line = self.lines.get(timeout=min(left, 0.25))
            except queue.Empty:
                continue
            if line is None:
                self.close(grace=0.1)
                if self.result is None and self.error is None:
                    self.error = {"tool": "referee", "exit": self.proc.returncode if self.proc else None,
                                  "kind": "run",
                                  "message": (f"game {self.ident}: the kept referee went away without a result"
                                              if self.kept else
                                              f"game {self.ident}: the referee ended without a result"),
                                  "stderr": self.stderr_tail()}
                self.pending = None
                return self._state(refused, render=render)
            try:
                record = json.loads(line)
            except ValueError:
                print(f"shandalar_mcp: game {self.ident}: not JSON: {line.rstrip()[:120]}",
                      file=sys.stderr)
                continue
            if not isinstance(record, dict):
                continue
            if "error" in record:
                self.error = record["error"] if isinstance(record["error"], dict) else {"message": str(record)}
                self.pending = None
                return self._state(refused, render=render)
            kind = record.get("type")
            if kind == "hello":
                self.hello = record
            elif kind == "table":
                self.table = record
                if until_table:
                    return self._state(refused, pending=True, render=render)
            elif kind == "resume":
                # A kept referee taken up again: its counters are the truth,
                # and they count the decision it replays next (`n`).
                self.decisions = int(record.get("decisions", self.decisions))
                self.refusals = int(record.get("refusals", self.refusals))
                self.last_decision_n = int(record.get("n", 0)) if record.get("awaiting") else None
                self.last_brief = None
            elif kind == "refused":
                self.refusals += 1
                refused.append(record)
                strikes = self.memory.setdefault("strikes", {})
                strikes[int(record.get("n", -1))] = strikes.get(int(record.get("n", -1)), 0) + 1
            elif kind == "decision":
                number = int(record.get("n", 0))
                if number != self.last_decision_n:
                    self.decisions += 1
                self.last_decision_n = number
                self.pending = record
                return self._state(refused, render=render)
            elif kind == "result":
                self.result = record
                self.pending = None
                return self._state(refused, render=render)

    def _state(self, refused: list[dict], pending: bool = False, render: bool = True) -> dict:
        out: dict = {"game": self.ident, "decisions": self.decisions, "refusals": self.refusals}
        if refused:
            out["refused"] = refused
        if self.table is not None and self.hello is None:
            out["table"] = self.table
        if pending:
            out["pending"] = True
            out["note"] = ("the table is open and the chair is held for a guest; referee_wait reads on "
                           "(hello and the first decision come when they sit down and the duel starts)"
                           if self.table is not None and self.hello is None else
                           "nothing arrived in time; referee_wait reads on")
        elif self.pending is not None and render:
            out["decision"] = self.shown()
        if self.result is not None:
            out["result"] = self.result
        if self.error is not None:
            out["error"] = self.error
        return out

    def shown(self) -> dict:
        """The pending decision as the client sees it, in the game's
        view; the journal of decisions passed over is put back in front
        of its own, and the brief becomes the next delta's base."""
        assert self.pending is not None
        if self.passed_journal:
            view = dict(self.pending.get("view") or {})
            view["journal"] = self.passed_journal + list(view.get("journal") or [])
            self.pending["view"] = view
            self.passed_journal = []
        brief = brief_view(self.pending.get("view", {}), int(self.pending.get("seat", 0)))
        out = render_decision(self.pending, self.view, self.last_brief, brief)
        self.last_brief = brief
        return out

    def stderr_tail(self, lines: int = 12) -> list[str]:
        try:
            if not self.stderr_file.closed:
                self.stderr_file.flush()
            text = Path(self.stderr_file.name).read_text(encoding="utf-8", errors="replace")
        except OSError:
            return []
        return text.splitlines()[-lines:]

    def close(self, grace: float = 10.0) -> None:
        self.transport.close(grace)
        self.closed = True
        self.pump.join(timeout=1)
        if self.proc is not None and not self.pump.is_alive() and self.proc.stdout is not None:
            self.proc.stdout.close()
        try:
            self.stderr_file.close()
        except OSError:
            pass

    def detach(self) -> None:
        """Let a kept referee go on without this server: the socket is
        closed, the process is not touched."""
        self.transport.close(0)
        self.closed = True
        self.pump.join(timeout=1)
        try:
            self.stderr_file.close()
        except OSError:
            pass

    def summary(self) -> dict:
        out = {"game": self.ident, "running": self.running, "view": self.view,
               "decisions": self.decisions, "refusals": self.refusals,
               "seconds": round(time.time() - self.started, 1), "argv": self.argv[1:]}
        if self.kept:
            out["kept"] = True
        if self.table is not None:
            out["hosted"] = self.table
        if self.hello is not None:
            out["seats"] = self.hello.get("seats")
            out["seed"] = self.hello.get("seed")
            if self.hello.get("table"):
                out["table"] = self.hello["table"]
        if self.pending is not None:
            out["pending"] = {k: self.pending.get(k) for k in ("n", "seat", "mode", "turn", "step")}
        if self.result is not None:
            out["result"] = self.result
        if self.error is not None:
            out["error"] = self.error
        return out


# --- the tools --------------------------------------------------------------

def prop(kind: str, description: str, **more) -> dict:
    out = {"type": kind, "description": description}
    out.update(more)
    return out


def validate_argument(value, schema: dict, tool: str, flag: str) -> None:
    """Enforce the types/bounds we advertise before invoking a tool.

    bool is an int in Python, but not in JSON Schema; NaN/Infinity are not
    portable JSON numbers and cannot be process timeouts.
    """
    types = schema.get("type", [])
    types = [types] if isinstance(types, str) else types
    checks = {"string": isinstance(value, str), "object": isinstance(value, dict),
              "array": isinstance(value, list), "boolean": isinstance(value, bool),
              "integer": isinstance(value, int) and not isinstance(value, bool),
              "number": isinstance(value, (int, float)) and not isinstance(value, bool)}
    if types and not any(checks.get(kind, False) for kind in types):
        raise refusal(tool, "option", f"`{flag}` must be {' or '.join(types)}", flag=flag)
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if (isinstance(value, float) and not math.isfinite(value)
                or "minimum" in schema and value < schema["minimum"]
                or "maximum" in schema and value > schema["maximum"]
                or "exclusiveMinimum" in schema and value <= schema["exclusiveMinimum"]):
            raise refusal(tool, "option", f"`{flag}` is outside its allowed range", flag=flag)
    if "enum" in schema and value not in schema["enum"]:
        near = difflib.get_close_matches(value, schema["enum"], n=3) if isinstance(value, str) else []
        raise refusal(tool, "option", f"`{flag}` must be one of {schema['enum']}", flag=flag,
                      suggestions=near)
    if isinstance(value, list):
        if len(value) < schema.get("minItems", 0):
            raise refusal(tool, "option", f"`{flag}` needs at least {schema['minItems']} items", flag=flag)
        for item in value:
            validate_argument(item, schema.get("items", {}), tool, flag)


STRING_LIST = {"type": "array", "items": {"type": "string"}}


class Server:
    def __init__(self, door: Path, workspace: Path):
        self.door = door.resolve()
        self.root = self.door.parent
        self.native = self.door.name.lower() == WINDOWS_DOOR.lower()
        self.workspace = workspace if workspace.is_absolute() else (self.root / workspace)
        self.workspace = self.workspace.resolve()
        self.games: dict[str, Game] = {}
        # Games are numbered past every file a game left in the folder —
        # a kept record, a transcript — so nothing of an earlier server's
        # is written over.
        self.next_game = 1
        games = self.workspace / "games"
        for path in games.iterdir() if games.is_dir() else []:
            found = re.match(r"g(\d+)\.", path.name)
            if found:
                self.next_game = max(self.next_game, int(found.group(1)) + 1)
        self.version_cache: str | None = None
        self.tools = self._catalogue()
        # THE CALL IN FLIGHT (2026-10-03). Requests are answered one at a
        # time, in order, on a worker thread, while the reader thread keeps
        # reading: a `ping` is answered at once and `notifications/cancelled`
        # sets the in-flight call's event — the door's child is killed, a
        # referee wait stops, and the call is not answered. Before this a
        # cancelled fifteen-minute Lab run held every later request behind
        # it until it finished on its own.
        self.write_lock = threading.Lock()
        self.flight_lock = threading.RLock()   # re-entered by the SIGTERM handler
        self.flight_id = None
        self.flight_cancel = threading.Event()
        self.cancelled_ids: set = set()
        self.children: set = set()
        self.stopping = False
        # PROGRESS (2026-10-03): the `_meta.progressToken` of the call in
        # flight, and where its `notifications/progress` go (the sink
        # `serve` writes to; None when a test calls a tool directly).
        self.flight_progress = None
        self.sink = None

    # ----- the door ---------------------------------------------------------

    def command(self, verb: str, args: list[str]) -> list[str]:
        """One route for batch tools AND the persistent referee. Launch the
        Windows console executable directly: no Bash, cmd.exe or .bat quoting."""
        if not self.native:
            return [str(self.door), verb, *args]
        routes = {"lab": ["--deck-lab"], "autodeck": ["--auto-deck"],
                  "referee": ["--referee"], "query": ["--lab-query"],
                  **{v: ["--lab-query", v] for v in ("packs", "cards", "check")}}
        if verb not in routes:
            message = ("Deck conversion requires the source checkout's deck converter."
                       if verb == "convert" else f"No native release command '{verb}'.")
            raise refusal("shandalar", "option", message, flag=verb)
        return [str(self.door), "--headless", "--no-header", "--", *routes[verb], *args]

    def is_cancelled(self) -> bool:
        return self.stopping or self.flight_cancel.is_set()

    def run(self, verb: str, args: list[str], timeout: float = DEFAULT_TIMEOUT,
            on_stderr=None) -> subprocess.CompletedProcess:
        """One door verb to its end, its output captured. The child runs in
        a process group of its own, so a timeout or a cancellation stops the
        whole of it — the Lab's worker processes too — not just the door.
        With [on_stderr], each stderr line is handed to it as it arrives
        (the Lab's `--progress json` lines) instead of only at the end."""
        if on_stderr is not None:
            return self._run_streaming(verb, args, timeout, on_stderr)
        env = dict(os.environ)
        env["SHANDALAR_NO_BANNER"] = "1"
        env["NO_COLOR"] = "1"
        argv = self.command(verb, args)
        try:
            proc = subprocess.Popen(argv, cwd=str(self.root), stdin=subprocess.DEVNULL,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                    encoding="utf-8", errors="replace", env=env, **own_group())
        except OSError as exc:
            raise refusal("shandalar", "door", f"the door {self.door} would not run: {exc}", exit_code=3)
        with self.flight_lock:
            self.children.add(proc)
        deadline = time.monotonic() + timeout
        try:
            while True:
                try:
                    out, err = proc.communicate(timeout=max(0.0, min(0.25, deadline - time.monotonic())))
                    break
                except subprocess.TimeoutExpired:
                    cancelled = self.is_cancelled()
                    if not cancelled and time.monotonic() < deadline:
                        continue
                    stop_tree(proc)
                    if cancelled:
                        raise Cancelled(f"{verb} was cancelled")
                    raise refusal(verb, "timeout", f"{verb} did not finish in {timeout:.0f} s", exit_code=1,
                                  argv=argv[1:], timeout=timeout)
        finally:
            with self.flight_lock:
                self.children.discard(proc)
        return subprocess.CompletedProcess(argv, proc.returncode, out, err)

    def _run_streaming(self, verb: str, args: list[str], timeout: float, on_stderr) -> subprocess.CompletedProcess:
        """`run` with stderr read line by line on a thread of its own (and
        stdout on another, so neither pipe can fill and stall the child)."""
        env = dict(os.environ)
        env["SHANDALAR_NO_BANNER"] = "1"
        env["NO_COLOR"] = "1"
        argv = self.command(verb, args)
        try:
            proc = subprocess.Popen(argv, cwd=str(self.root), stdin=subprocess.DEVNULL,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                    encoding="utf-8", errors="replace", env=env, **own_group())
        except OSError as exc:
            raise refusal("shandalar", "door", f"the door {self.door} would not run: {exc}", exit_code=3)
        out_parts: list[str] = []
        err_lines: list[str] = []

        def read_out() -> None:
            out_parts.append(proc.stdout.read())

        def read_err() -> None:
            for line in proc.stderr:
                err_lines.append(line)
                try:
                    on_stderr(line)
                except Exception as exc:  # noqa: BLE001 — a reader never kills the run
                    print(f"shandalar_mcp: progress: {type(exc).__name__}: {exc}", file=sys.stderr)

        readers = [threading.Thread(target=read_out, daemon=True), threading.Thread(target=read_err, daemon=True)]
        for reader in readers:
            reader.start()
        with self.flight_lock:
            self.children.add(proc)
        deadline = time.monotonic() + timeout
        try:
            while True:
                try:
                    proc.wait(timeout=max(0.0, min(0.25, deadline - time.monotonic())))
                    break
                except subprocess.TimeoutExpired:
                    cancelled = self.is_cancelled()
                    if not cancelled and time.monotonic() < deadline:
                        continue
                    stop_tree(proc, drain=False)
                    if cancelled:
                        raise Cancelled(f"{verb} was cancelled")
                    raise refusal(verb, "timeout", f"{verb} did not finish in {timeout:.0f} s", exit_code=1,
                                  argv=argv[1:], timeout=timeout)
        finally:
            with self.flight_lock:
                self.children.discard(proc)
            for reader in readers:
                reader.join(timeout=10)
        return subprocess.CompletedProcess(argv, proc.returncode, "".join(out_parts), "".join(err_lines))

    def progress_reporter(self):
        """A stderr-line reader that turns the Lab's `--progress json` lines
        into `notifications/progress` for the call in flight — or None when
        the client asked for no progress (no `_meta.progressToken`) or no
        client is listening."""
        token = self.flight_progress
        sink = self.sink
        if token is None or sink is None:
            return None
        last = {"done": -1}

        def report(line: str) -> None:
            text = line.strip()
            if not text.startswith("{"):
                return
            try:
                record = json.loads(text)
            except ValueError:
                return
            row = record.get("progress") if isinstance(record, dict) else None
            if not isinstance(row, dict):
                return
            done, total = row.get("done"), row.get("total")
            if not isinstance(done, int) or isinstance(done, bool) or done <= last["done"]:
                return   # MCP: progress only ever increases
            last["done"] = done
            params: dict = {"progressToken": token, "progress": done}
            if isinstance(total, int) and not isinstance(total, bool) and total > 0:
                params["total"] = total
            unit = str(row.get("unit") or "games")
            params["message"] = (f"{done} of {total} {unit}" if "total" in params else f"{done} {unit}")
            self.emit(sink, {"jsonrpc": "2.0", "method": "notifications/progress", "params": params})

        return report

    @staticmethod
    def parse_stdout(done: subprocess.CompletedProcess):
        text = done.stdout.strip()
        if not text:
            return None
        try:
            return json.loads(text)
        except ValueError:
            return None

    def quote(self, verb: str, done: subprocess.CompletedProcess, ok=(0,), require_json=False):
        """The door's JSON, or its refusal raised as one."""
        parsed = self.parse_stdout(done)
        if done.returncode not in ok:
            if isinstance(parsed, dict) and isinstance(parsed.get("error"), dict):
                raise ToolError(parsed["error"])
            tail = [line for line in done.stderr.splitlines() if line.strip()][-8:]
            kind = "godot" if done.returncode == 3 else "run"
            message = tail[-1] if tail else f"{verb} exited {done.returncode}"
            raise refusal(verb, kind, message, exit_code=done.returncode, stderr=tail)
        if require_json and not isinstance(parsed, dict):
            raise refusal(verb, "run", f"{verb} did not return the expected JSON object", exit_code=1,
                          stderr=done.stderr.splitlines()[-8:])
        return parsed

    def version(self) -> str:
        if self.version_cache is None:
            if self.native:
                # --version on the executable is GODOT's version, not the game.
                # The packager generates this from project.godot, like the shell door.
                try:
                    value = (self.root / "VERSION.txt").read_text(encoding="utf-8").strip()
                except (OSError, UnicodeError):
                    value = ""
                self.version_cache = value if re.fullmatch(
                    r"[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?", value) else ""
                return self.version_cache
            try:
                done = self.run("-V", [], timeout=60)
                found = re.search(r"\d+\.\d+\.\d+\S*", done.stdout)
                self.version_cache = found.group(0) if found else ""
            except ToolError:
                self.version_cache = ""
        return self.version_cache

    # ----- paths --------------------------------------------------------------

    def inside(self, text, tool: str, flag: str) -> Path:
        """A path a tool writes: under the checkout or the workspace."""
        if not isinstance(text, str) or not text.strip():
            raise refusal(tool, "option", f"`{flag}` is a path", flag=flag)
        path = Path(text)
        if not path.is_absolute():
            path = self.root / path
        resolved = path.resolve()
        for home in (self.root, self.workspace):
            if resolved == home or home in resolved.parents:
                return resolved
        raise refusal(tool, "path", f"`{flag}` must lie under {self.root} or {self.workspace}: {text}",
                      flag=flag, path=text)

    def spoken(self, path: Path) -> str:
        try:
            return str(path.relative_to(self.root))
        except ValueError:
            return str(path)

    def read_json(self, path: Path, tool: str) -> dict:
        """A JSON object a run left on disk (`run.json`, `results.json`).
        One that is half-written (a run still going, a run that was
        killed) or not an object is a refusal with its path — before
        2026-10-03 it escaped as a protocol-level internal error."""
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, ValueError) as exc:
            raise refusal(tool, "run", f"{self.spoken(path)} could not be read as JSON: {exc}",
                          exit_code=1, path=self.spoken(path))
        if not isinstance(data, dict):
            raise refusal(tool, "run", f"{self.spoken(path)} is not a JSON object", exit_code=1,
                          path=self.spoken(path))
        return data

    def default_out(self, tool: str) -> Path:
        """A fresh run folder under the workspace (`runs/lab-STAMP`), for a
        run whose line names none: where the module docstring and
        .gitignore say a client's runs go, and a folder `read_run` reads."""
        base = self.workspace / "runs" / f"{tool}-{time.strftime('%Y%m%d-%H%M%S')}"
        path, n = base, 1
        while path.exists():
            n += 1
            path = base.with_name(f"{base.name}-{n}")
        return path

    def deck_arg(self, text) -> str:
        """A deck a tool names for the door. As typed when the door will find it
        itself (an absolute path, a path under the checkout or under `decks/`);
        a file or folder in the workspace — where `write_deck` and the AutoDeck
        put theirs — by its bare name, handed over as an absolute path; anything
        else as typed, so `random` and the door's own words pass through and the
        door's refusal (with what it tried) is the answer."""
        text = str(text)
        if not text.strip() or Path(text).is_absolute():
            return text
        for candidate in (self.root / text, self.root / "decks" / text):
            if candidate.exists():
                return text
        mine = self.workspace / text
        if mine.exists():
            return str(mine.resolve())
        return text

    def deck_list(self, text) -> str:
        """A comma list of decks (or one folder), each item resolved like `deck_arg`."""
        return ",".join(self.deck_arg(item.strip()) for item in str(text).split(","))

    # ----- the catalogue ----------------------------------------------------

    def _catalogue(self) -> list[dict]:
        seat = prop("string", "who plays this seat: `agent` is you, the client on this pipe; "
                    "`apprentice`, `magician`, `sorcerer`, `wizard` the shipped computer players "
                    "(weakest to strongest); `unfair` the wizard that reads hidden cards",
                    enum=list(SEATS))
        view = prop("string", "how each decision's board is rendered: `brief` (default) is the "
                    "board, the hand with costs and castable marks, and the new journal lines; "
                    "`delta` only what changed since the decision you last saw (life, cards that "
                    "came and went, the stack, the prompts, the journal; the first one is the "
                    "whole brief, marked `baseline`); `full` the referee's whole LAN view; "
                    "`options` the legal answers alone",
                    enum=list(VIEWS))
        keep = prop("boolean", "keep the game across this server's restarts: the referee listens "
                    "on a loopback socket and outlives the client; `referee_resume` takes it up "
                    "again (a kept game idle for 30 minutes concedes)")
        game = prop("string", "the game id `referee_start`, `referee_join` or `referee_host` returned (`g1`)")
        timeout = prop("number", "seconds to wait for the next line (default 120); a `pending` "
                       "answer means it did not arrive yet — `referee_wait` reads on")
        packs = prop("string", "the card packs in play: `all`, `none`, or ids `1,3` (unset: the "
                     "game's own setting)")
        out = prop("string", "the output folder, under the checkout or the workspace")
        return [
            self._tool("status", "The server, the folders and the games: the door it drives, the "
                       "project version, the workspace where a client's decks and runs go, and "
                       "every referee game this session opened with its state. Call it first.",
                       {}, self.tool_status),
            self._tool("contract", "The whole contract page (AGENTS.md): every command-line tool, "
                       "its channels, exit codes, files and JSON keys — the reference behind "
                       "these tools.", {}, self.tool_contract),
            self._tool("play_guide", "Learn to play MTG fairly: rules, timing, tactical combat, "
                       "worked decisions and deck-building strategy. Reads documentation only; "
                       "omit chapter for the full guide, or request one of its 16 chapters.",
                       {"chapter": prop("integer", "chapter number, 1-16; 8 is combat, "
                                        "9 game-specific rules, 16 deck building",
                                        minimum=1, maximum=16)}, self.tool_play_guide),
            self._tool("manual", "One tool's own `--help` text: `lab` (the Deck Lab), `autodeck`, "
                       "`query` (check/packs/cards), `referee`, `convert`, or `door` (the verb list).",
                       {"verb": prop("string", "which manual", enum=list(MANUALS))},
                       self.tool_manual, required=["verb"]),
            self._tool("packs", "Every card pack: `known`, `available` (found), `enabled` (on), and "
                       "per pack its id, label, path, sets, card count and why a found zip was "
                       "rejected. A deck that needs a pack that is off is not playable.",
                       {}, self.tool_packs),
            self._tool("cards", "A card's record by exact printed name: cost, mana value, colors, "
                       "types, keywords, power/toughness, rules text, printings, rarity, pack. An "
                       "unknown name answers `known: false` with `near` — the nearest real names.",
                       {"names": prop("array", "one or more exact card names", items={"type": "string"},
                                      minItems=1)},
                       self.tool_cards, required=["names"]),
            self._tool("list_decks", "The deck files: the shipped `decks/` folder (its groups are "
                       "the subfolders — `tournament` is the good decks) and the workspace, each "
                       "with its name and card counts read from the file. Search by name/path "
                       "and page with offset/limit; count is the total matching decks.",
                       {"folder": prop("string", "one folder instead (under the checkout or the "
                                       "workspace; `workspace` is the workspace itself), "
                                       "searched recursively"),
                        "search": prop("string", "case-insensitive part of a deck name or path"),
                        "offset": prop("integer", "skip this many matching decks (default 0)", minimum=0),
                        "limit": prop("integer", "maximum decks to return (unset: all)", minimum=1)},
                       self.tool_list_decks),
            self._tool("read_deck", "One deck file: its name, main deck and sideboard rows, the "
                       "counts, and the raw text. `.dck` (the original's format) is returned raw "
                       "— `convert_deck` turns it into `.deck`.",
                       {"deck": prop("string", "the deck path, as typed, under `decks/` or in the workspace")},
                       self.tool_read_deck, required=["deck"]),
            self._tool("write_deck", "Write a deck file from rows ('4 Lightning Bolt' or "
                       "{count, name}) and check it with the engine: the answer is `check_deck`'s "
                       "— `playable`, the unknown names with the nearest real ones, the packs "
                       "needed. The file goes under the workspace unless the path says otherwise.",
                       {"file": prop("string", "the file to write, `.deck`; relative paths land in "
                                     "the workspace"),
                        "name": prop("string", "the deck's name (the `name:` header)"),
                        "cards": {"description": "the main deck: rows of 'COUNT Card Name', "
                                  "objects {count, name}, or one string of lines",
                                  "type": ["array", "string"]},
                        "sideboard": {"description": "the sideboard rows, the same shapes",
                                      "type": ["array", "string"]},
                        "force": prop("boolean", "overwrite a file that is there (default false)"),
                        "check": prop("boolean", "run the engine's check after writing (default "
                                      "true; false writes without an engine)"),
                        "packs": packs, "format": prop("string", "a deck format to require: "
                                                       "unrestricted|wild|type1|type1.5|highlander")},
                       self.tool_write_deck, required=["file", "cards"]),
            self._tool("check_deck", "Is this deck playable, and why not: each deck's name, card "
                       "counts, line errors, `unknown` names (with `pack` — the pack that supplies "
                       "it — and `near`), `packs_needed`, `packs_missing`, the format verdict and "
                       "`playable`. Exit 0 is an answer even for a deck that cannot be played.",
                       {"decks": prop("array", "deck paths, as typed, under `decks/` or in the workspace",
                                      items={"type": "string"}, minItems=1),
                        "packs": packs,
                        "format": prop("string", "require a format: unrestricted|wild|type1|type1.5|highlander")},
                       self.tool_check_deck, required=["decks"]),
            self._tool("convert_deck", "Convert a deck between `.deck`/`.dec` (the community "
                       "format) and `.dck` (the original MicroProse format); the formats come "
                       "from the extensions.",
                       {"input": prop("string", "the deck to read"),
                        "output": prop("string", "the file to write, under the checkout or the workspace")},
                       self.tool_convert_deck, required=["input", "output"]),
            self._tool("autodeck", "Build decks by the dozen or the thousand from wishes — the "
                       "field the Lab measures. Every axis takes a comma list of alternatives and "
                       "the run walks their product `count` times. Answers with the run's "
                       "`run.json`, the deck files it wrote and the Lab line that plays them "
                       "(`next`); `dry_run` answers with the plan and writes nothing.",
                       {"out": out, "count": prop("integer", "how many decks (default 10)", minimum=1),
                        "seed": prop("integer", "the seed (unset: rolled and reported)"),
                        "colors": prop("string", "`G`, `WU`, `=WU` (exactly), `none`, `random`, "
                                       "`pairs`, or a comma list of alternatives"),
                        "max_colors": prop("integer", "1..5 (default 2)"),
                        "sets": prop("string", "set codes, comma-separated (`4ed,ice`)"),
                        "source": prop("string", "`sets`, `list` or `sealed`"),
                        "packs": packs,
                        "size": prop("integer", "40 or 60 (default 60)"),
                        "lean": prop("string", "`creatures`, `balanced` or `spells`"),
                        "speed": prop("string", "`fast`, `medium` or `slow`"),
                        "gold": prop("string", "`on` or `off`: prefer multicolored cards"),
                        "rarity": prop("string", "`any`, `pauper`, `no-rares`, `uncommon-up`, `rares`"),
                        "variety": prop("integer", "0, 25, 50 or 100: how far a seed's taste moves a card's worth"),
                        "distinct": prop("integer", "percent of cards that must differ between decks"),
                        "keep": prop("string", "build every deck around this deck's non-land cards"),
                        "vary": prop("string", "with `keep`: hold the deck but for these cards, `\"2 Card, 1 Other\"`"),
                        "force": prop("boolean", "write into a folder that already holds a run"),
                        "dry_run": prop("boolean", "the plan as JSON, nothing written"),
                        "extra_args": prop("array", "any other switch, as the command line takes it "
                                           "(`manual autodeck` lists them)", items={"type": "string"}),
                        "timeout": prop("number", "seconds to allow the run (default 900)")},
                       self.tool_autodeck, required=["out"]),
            self._tool("lab", "The Deck Lab: play decks against decks headless, on every core, and "
                       "report each win rate with the interval that says how much of it to "
                       "believe. Modes by argument: `deck_a`+`deck_b` a duel; `deck_a`+`gauntlet` "
                       "one deck against a group; `matrix` every pair; `field`+`gauntlet` a "
                       "tournament that ranks the field; `deck_b: random` a deck against the "
                       "field; `sweep` one AI knob with a control pair. Answers with the report, "
                       "`run.json` (its `next.argv` is the run that settles what this one left "
                       "open) and `results.json`/`sweep.json` (matchups trimmed to `limit`). "
                       "`dry_run` answers with the plan and plays nothing. Runs are not rated "
                       "unless `rated` is true.",
                       {"deck_a": prop("string", "the deck under test, as typed, under `decks/` "
                                       "or in the workspace (a deck `write_deck` wrote, by its file name)"),
                        "deck_b": prop("string", "the opponent, or `random`"),
                        "gauntlet": prop("string", "the opponent pool: a comma list of decks or a folder"),
                        "matrix": prop("string", "a round-robin pool: a comma list or a folder"),
                        "field": prop("string", "the decks under test in a tournament: a list, a "
                                      "folder, or a text file naming one deck a line (the "
                                      "AutoDeck's decklist.txt, a previous run's top.txt)"),
                        "deck_pool": prop("string", "what `random` draws from (default decks/)"),
                        "group": prop("string", "one group of an expanded folder (`tournament`)"),
                        "games": prop("integer", "games per matchup (default 1000 — 20..200 for a first look)", minimum=1),
                        "seed": prop("integer", "the base seed (default 1); one seed replays one run"),
                        "jobs": prop("integer", "worker threads in a process"),
                        "procs": prop("integer", "worker processes (default 8 once a run is big enough; 1 turns it off)"),
                        "packs": packs,
                        "profile_a": prop("string", "the AI piloting deck A: apprentice|magician|sorcerer|wizard, `wizard:knob=v`"),
                        "profile_b": prop("string", "the AI piloting deck B"),
                        "top": prop("integer", "tournament: how many of the field's best to detail"),
                        "best_of": prop("integer", "play matches of up to N duels"),
                        "sideboard": prop("string", "`on` or `off`: let the AI swap sideboards between duels"),
                        "rules": prop("string", "`fifth` or `modern`"),
                        "format": prop("string", "require a deck format"),
                        "lives": prop("string", "starting life, `20,20`"),
                        "mulligan": prop("string", "`on` or `off`"),
                        "sweep": prop("string", "one AI knob and its values, `KNOB=V1,V2`"),
                        "null": prop("string", "the sweep knob's null value"),
                        "control_deck_a": prop("string", "the sweep's control pair, deck A"),
                        "control_deck_b": prop("string", "the sweep's control pair, deck B"),
                        "record": prop("string", "keep the engine's log of some games: `losses`, `stalls` or `all`"),
                        "record_max": prop("integer", "at most this many recorded games (default 50)"),
                        "out": out,
                        "rated": prop("boolean", "update the Elo ledger (default false: `--no-elo`)"),
                        "dry_run": prop("boolean", "the plan as JSON, nothing played"),
                        "argv": prop("array", "a whole Deck Lab line instead of the arguments above "
                                     "— what `run.json`'s `next.argv` holds", items={"type": "string"}),
                        "extra_args": prop("array", "any other switch, as the command line takes it "
                                           "(`manual lab` lists them)", items={"type": "string"}),
                        "limit": prop("integer", "how many matchups and standings rows to return (default 50)"),
                        "timeout": prop("number", "seconds to allow the run (default 900)")},
                       self.tool_lab),
            self._tool("lab_resume", "Finish a Deck Lab run that was interrupted: the run whose "
                       "`run.json` says `exit: null` beside a `checkpoint.jsonl`. The games "
                       "already played are kept; the rest are played; the report is written as "
                       "if nothing had happened.",
                       {"out": prop("string", "the interrupted run's folder"),
                        "limit": prop("integer", "matchups and standings rows to return (default 50)"),
                        "timeout": prop("number", "seconds to allow the run (default 900)")},
                       self.tool_lab_resume, required=["out"]),
            self._tool("read_run", "Read a finished run: its `run.json` (the line as typed, the "
                       "exit, what was written, and `next` — the run that would settle what this "
                       "one left open), its `results.json` or `sweep.json` (matchups and standings "
                       "trimmed to `limit`), the report text, and the files in the folder.",
                       {"out": prop("string", "the run's folder"),
                        "limit": prop("integer", "matchups and standings rows to return (default 50)")},
                       self.tool_read_run, required=["out"]),
            self._tool("lab_next", "Run what a finished run left open: read `run.json`'s "
                       "`next.argv` and play that line (more games for the matchups still "
                       "straddling even, the tournament's top decks at more games, an AutoDeck "
                       "field into the Lab). Answers `next: null` when nothing is open.",
                       {"out": prop("string", "the finished run's folder"),
                        "limit": prop("integer", "matchups and standings rows to return (default 50)"),
                        "timeout": prop("number", "seconds to allow the run (default 900)")},
                       self.tool_lab_next, required=["out"]),
            self._tool("referee_start", "Open one duel and return its first decision. You (the "
                       "`agent` seat) play against a computer player, or take both seats and play "
                       "yourself. The answer carries `hello` (seats, seed, toss, the ops) and the "
                       "pending `decision`: its `seat`, `mode`, `options` (the legal answers, each "
                       "with the op it takes) and the board. Answer with `referee_act`; the game "
                       "waits between calls.",
                       {"deck_a": prop("string", "seat 0's deck, as typed, under `decks/` or in the workspace"),
                        "deck_b": prop("string", "seat 1's deck"),
                        "seat_a": seat, "seat_b": seat,
                        "seed": prop("integer", "the shuffle (unset: drawn and reported in `hello`)"),
                        "turns": prop("integer", "the duel is a draw past this turn (default 200)"),
                        "packs": packs,
                        "log": prop("string", "write the engine's own log of the duel here at the end"),
                        "keep": keep, "view": view, "timeout": timeout},
                       self.tool_referee_start, required=["deck_a", "deck_b"]),
            self._tool("referee_join", "Sit at a table a person (or another program) hosts in the "
                       "game — play against a human. Takes the LAN invitation (`sglan1:...`) the "
                       "host's screen shows, the same-computer access code with `port`, or — for "
                       "a table hosted open on the LAN — the table's `name` as the host typed it. "
                       "The answer arrives when the table starts; until then `pending` is true and "
                       "`referee_wait` reads on. The host sees an ordinary guest. Kept by default "
                       "(`keep: false` to end it with this server).",
                       {"invitation": prop("string", "the invitation or access code"),
                        "table": prop("string", "an open table's name, found by LAN discovery (instead of `invitation`)"),
                        "deck": prop("string", "the deck this seat brings, as typed, under `decks/` or in the workspace"),
                        "port": prop("integer", "the host's port for an access code (default 17897)"),
                        "name": prop("string", "this seat's nickname at the table"),
                        "wait": prop("integer", "seconds to wait for the table (default 300)"),
                        "turns": prop("integer", "the duel is a draw past this turn"),
                        "log": prop("string", "write the journal this seat saw — every line of the game "
                                    "as the table told it — here at the end"),
                        "packs": packs, "keep": keep, "view": view,
                        "timeout": prop("number", "seconds to wait for the first decision before "
                                        "answering `pending` (default 15)")},
                       self.tool_referee_join, required=["deck"]),
            self._tool("referee_host", "Host a table yourself and wait for a person to sit down — "
                       "the referee runs the game's own LAN host, opens one table of that `name` with "
                       "you in seat 0, and answers at once with `table`: the name, the `access` rule, "
                       "the host's address and port, the `invitation`, and whether the advert went "
                       "out. `open` (default): the table is listed in every Game Browser on the LAN "
                       "and the person joins it by name — tell them the table name. `invitation`: the "
                       "table is listed without its secret and the person pastes the `invitation` "
                       "into the game's Join screen — hand it to them. Then `referee_wait` reads on "
                       "until they sit down: `hello` and the first decision come when the duel "
                       "starts; `wait` is how long the empty chair is held. The table lives as long "
                       "as the duel. Kept by default (`keep: false` to end it with this server).",
                       {"table": prop("string", "the table's name as the Game Browser will list it "
                                      "(1-32 plain characters)"),
                        "deck": prop("string", "the deck you bring, as typed, under `decks/` or in the workspace"),
                        "access": prop("string", "`open` (joined by name from the Game Browser; default) "
                                       "or `invitation` (pasted)", enum=list(ACCESS)),
                        "name": prop("string", "your nickname at the table (default Agent)"),
                        "port": prop("integer", "the port to host on (default 17897; 0 any free port)"),
                        "address": prop("string", "the LAN address to host on (default: this "
                                        "computer's first private IPv4)"),
                        "wait": prop("integer", "seconds to hold the empty chair for a guest (default 300)"),
                        "turns": prop("integer", "the duel is a draw past this turn"),
                        "log": prop("string", "write the journal your seat saw here at the end"),
                        "packs": packs, "keep": keep, "view": view,
                        "timeout": prop("number", "seconds to wait for the `table` line before "
                                        "answering `pending` (default 15)")},
                       self.tool_referee_host, required=["table", "deck"]),
            self._tool("referee_act", "Answer the pending decision of a game and return the next "
                       "one (or the `result`). `action` is one of the decision's `options` as the "
                       "wire takes it — `{\"op\":\"pass\"}`, `{\"op\":\"play\",\"card\":\"c3\"}`, "
                       "`{\"op\":\"attack\",\"cards\":[...]}` — or the string `default` for the "
                       "built-in pilot's answer (it ACTS: to read a decision again, `referee_wait`). "
                       "A `refused` entry means the answer could not be applied and the same "
                       "decision is back; the pilot concedes after three refusals. With `until`, "
                       "the server then passes priority for you up to the next point a player "
                       "would act — `main` your own main phase, `end` this turn's end step, `turn` "
                       "your next turn, `play` your main phase with something to play, `respond` "
                       "only a reaction window — and every value stops where a real player would: "
                       "a spell or ability of the opponent's on the stack while you hold an answer "
                       "(counter it, respond to it), their declared attack, their blocks and their "
                       "end step while you hold an instant or an ability (Lightning Bolt mid-fight, "
                       "end-of-turn plays), the blocks on your own turn, and every attack, block, "
                       "discard, damage and choice of your own. The answer says `stop` (why it "
                       "stopped), `passed` (decisions passed), and the journal of everything "
                       "passed over is in the decision shown.",
                       {"game": game,
                        "action": {"description": "the answer: an object with `op` (the seat is "
                                   "filled in), or `default`", "type": ["object", "string"]},
                        "until": prop("string", "pass priority after this answer up to: `main`, `end`, "
                                      "`turn`, `play`, `respond` (unset: the next decision)", enum=list(UNTIL)),
                        "view": view, "timeout": timeout},
                       self.tool_referee_act, required=["game", "action"]),
            self._tool("referee_autoplay", "Let the built-in pilot answer the game's next "
                       "decisions — keep, play a land, cast the first spell, attack with "
                       "everything, block nothing — for `decisions` decisions or until the "
                       "`result`. A way to skip to the part you care about, or to watch a duel "
                       "run to its end.",
                       {"game": game,
                        "decisions": prop("integer", "how many decisions to play (unset: to the result)", minimum=1),
                        "view": view, "timeout": timeout},
                       self.tool_referee_autoplay, required=["game"]),
            self._tool("referee_wait", "Read the game's pending decision again, or wait for the "
                       "next line when the last answer was `pending` (a table not yet started, a "
                       "hosted chair still empty, a person still thinking).",
                       {"game": game, "view": view, "timeout": timeout},
                       self.tool_referee_wait, required=["game"]),
            self._tool("referee_stop", "End a game: the pipe is closed, the referee writes its "
                       "`result` (`reason: eof`) and exits; a kept game's seat concedes. A game "
                       "that already ended answers its result.",
                       {"game": game}, self.tool_referee_stop, required=["game"]),
            self._tool("referee_resume", "Take up a kept game again — one started with `keep` by "
                       "this server or an earlier one (a joined or hosted table is kept by default). Without "
                       "`game`, lists the kept games on record and the live ones. With it, "
                       "reconnects to that referee and returns `hello` and the pending decision "
                       "(the journal it carries is the whole game so far), or the result the "
                       "referee wrote while nobody was attached.",
                       {"game": prop("string", "the kept game's id (`g3`); unset lists them"),
                        "view": view,
                        "timeout": prop("number", "seconds to wait for the referee's answer (default 30)")},
                       self.tool_referee_resume),
        ]

    @staticmethod
    def _tool(name: str, description: str, properties: dict, handler, required: list[str] | None = None) -> dict:
        if "timeout" in properties:
            properties["timeout"] = {**properties["timeout"], "exclusiveMinimum": 0}
        for key in ("limit", "decisions"):
            if key in properties:
                properties[key] = {**properties[key], "minimum": 1}
        schema: dict = {"type": "object", "properties": properties, "additionalProperties": False}
        if required:
            schema["required"] = list(required)
        return {"name": name, "description": description, "inputSchema": schema, "handler": handler}

    def listing(self) -> list[dict]:
        return [{k: v for k, v in tool.items() if k != "handler"} for tool in self.tools]

    def call(self, name: str, arguments) -> dict:
        tool = next((t for t in self.tools if t["name"] == name), None)
        if tool is None:
            near = difflib.get_close_matches(str(name), [t["name"] for t in self.tools], n=3)
            raise UnknownTool(str(name), near)
        if arguments is None:
            arguments = {}
        if not isinstance(arguments, dict):
            raise refusal(name, "option", "arguments are an object")
        schema = tool["inputSchema"]
        known = schema["properties"]
        for key in arguments:
            if key not in known:
                near = difflib.get_close_matches(key, list(known), n=3)
                raise refusal(name, "option", f"{name} takes no argument `{key}`", flag=key,
                              suggestions=near, arguments=sorted(known))
        for key in schema.get("required", []):
            if key not in arguments or arguments[key] is None:
                raise refusal(name, "option", f"{name} needs `{key}`", flag=key)
        for key, value in arguments.items():
            validate_argument(value, known[key], name, key)
        return tool["handler"](arguments)

    # ----- the small tools ------------------------------------------------

    def tool_status(self, args: dict) -> dict:
        return {"server": SERVER_NAME, "version": self.version(), "door": str(self.door),
                "root": str(self.root), "workspace": str(self.workspace),
                "contract": str(self.root / CONTRACT), "tools": [t["name"] for t in self.tools],
                "games": [g.summary() for g in self.games.values()],
                "kept": [self.kept_summary(r) for r in self.kept_records() if r.get("game") not in self.games]}

    def tool_contract(self, args: dict) -> dict:
        path = self.root / CONTRACT
        if not path.is_file():
            raise refusal("shandalar", "path", f"{CONTRACT} is not beside the door", exit_code=1,
                          path=str(path))
        return {"file": str(path), "text": path.read_text(encoding="utf-8")}

    def tool_play_guide(self, args: dict) -> dict:
        chapter = args.get("chapter")
        if "chapter" in args and (type(chapter) is not int or not 1 <= chapter <= 16):
            raise refusal("play_guide", "option", "chapter must be an integer from 1 to 16",
                          flag="chapter")
        path = self.root / PLAY_GUIDE
        if not path.is_file():
            raise refusal("play_guide", "path", f"{PLAY_GUIDE} is not beside the door",
                          exit_code=1, path=str(path))
        text = path.read_text(encoding="utf-8")
        if chapter is not None:
            headings = list(re.finditer(r"^## ([1-9][0-9]*)\. .+$", text, re.MULTILINE))
            found = next((i for i, heading in enumerate(headings)
                          if int(heading.group(1)) == chapter), None)
            if found is None:
                raise refusal("play_guide", "guide", f"chapter {chapter} is missing from {PLAY_GUIDE}",
                              exit_code=1)
            end = headings[found + 1].start() if found + 1 < len(headings) else len(text)
            text = text[headings[found].start():end].rstrip() + "\n"
        return {"file": str(path), "chapter": chapter, "text": text}

    def tool_manual(self, args: dict) -> dict:
        verb = str(args["verb"])
        if verb not in MANUALS:
            raise refusal("shandalar", "option", f"no manual `{verb}`", flag="verb",
                          suggestions=difflib.get_close_matches(verb, MANUALS, n=3))
        if self.native and verb == "door":
            return {"verb": verb, "exit": 0,
                    "text": "Windows release tools: lab, autodeck, check, packs, cards, query, referee.\n"
                    "MCP launches Shandalar.console.exe directly; no shell is required.\n"
                    "Request each tool's manual for its arguments. Deck conversion requires a source checkout.\n"}
        argv = ["--help"] if verb == "door" else [verb, "--help"]
        done = self.run(argv[0], argv[1:], timeout=120)
        text = done.stdout if done.stdout.strip() else done.stderr
        return {"verb": verb, "exit": done.returncode, "text": text}

    def tool_packs(self, args: dict) -> dict:
        return self.quote("packs", self.run("packs", []), require_json=True)

    def tool_cards(self, args: dict) -> dict:
        names = self.strings(args["names"], "cards", "names")
        return self.quote("cards", self.run("cards", names), require_json=True)

    @staticmethod
    def strings(value, tool: str, flag: str) -> list[str]:
        if isinstance(value, str):
            value = [value]
        if not isinstance(value, list) or not value or not all(isinstance(v, str) and v.strip() for v in value):
            raise refusal(tool, "option", f"`{flag}` is a non-empty list of strings", flag=flag)
        return [v.strip() for v in value]

    def check_args(self, args: dict, decks: list[str]) -> list[str]:
        argv = [self.deck_arg(deck) for deck in decks]
        if args.get("packs"):
            argv += ["--packs", str(args["packs"])]
        if args.get("format"):
            argv += ["--format", str(args["format"])]
        return argv

    def tool_check_deck(self, args: dict) -> dict:
        decks = self.strings(args["decks"], "check_deck", "decks")
        return self.quote("check", self.run("check", self.check_args(args, decks)), require_json=True)

    def tool_convert_deck(self, args: dict) -> dict:
        source = self.deck_arg(args["input"])
        target = self.inside(args["output"], "convert", "output")
        done = self.run("convert", [source, str(target)], timeout=300)
        if done.returncode != 0:
            tail = [line for line in done.stderr.splitlines() if line.strip()][-6:]
            raise refusal("convert", "deck", tail[-1] if tail else f"convert exited {done.returncode}",
                          exit_code=done.returncode, stderr=tail)
        return {"input": source, "output": self.spoken(target), "report": done.stdout}

    # ----- decks --------------------------------------------------------------

    def deck_folders(self, args: dict) -> list[tuple[Path, str]]:
        if args.get("folder"):
            # The word `workspace` is the workspace wherever it lives; a
            # relative path is looked for under the checkout, then under the
            # workspace — the order `find_deck` reads a deck name in
            # (2026-10-02: with a `--workspace` elsewhere, "workspace" used
            # to name the checkout's own gitignored folder or nothing).
            typed = args["folder"]
            if isinstance(typed, str) and typed.strip() == "workspace":
                folder = self.workspace
            else:
                folder = self.inside(typed, "list_decks", "folder")
                if not folder.is_dir() and not Path(typed).is_absolute():
                    other = self.inside(str(self.workspace / typed), "list_decks", "folder")
                    if other.is_dir():
                        folder = other
            if not folder.is_dir():
                raise refusal("list_decks", "path", f"not a folder: {args['folder']}", path=str(args["folder"]))
            return [(folder, self.spoken(folder))]
        found = []
        for folder in (self.root / "decks", self.workspace):
            if folder.is_dir():
                found.append((folder, self.spoken(folder)))
        return found

    def tool_list_decks(self, args: dict) -> dict:
        decks = []
        seen = set()
        search = args.get("search", "").casefold()
        for folder, label in self.deck_folders(args):
            for path in sorted(folder.rglob("*")):
                if not path.is_file() or path.suffix.lower() not in (".deck", ".dec", ".dck"):
                    continue
                resolved = path.resolve()
                if resolved in seen:
                    continue
                seen.add(resolved)
                relative = path.relative_to(folder)
                group = relative.parts[0] if len(relative.parts) > 1 else ""
                row: dict = {"file": self.spoken(path), "folder": label, "group": group}
                if path.suffix.lower() == ".dck":
                    row["format"] = "dck"
                else:
                    try:
                        parsed = parse_deck(path.read_text(encoding="utf-8", errors="replace"))
                    except OSError:
                        continue
                    row["name"] = parsed["name"] or path.stem
                    row["cards"] = parsed["cards"]
                    row["sideboard"] = parsed["sideboard_cards"]
                    if parsed["errors"]:
                        row["errors"] = len(parsed["errors"])
                if not search or search in (row.get("name", "") + " " + row["file"]).casefold():
                    decks.append(row)
        offset = args.get("offset", 0)
        count = len(decks)
        page = decks[offset:offset + args.get("limit", count)]
        next_offset = offset + len(page)
        return {"decks": page, "count": count, "returned": len(page), "offset": offset,
                "next_offset": next_offset if next_offset < count else None}

    def find_deck(self, text: str, tool: str) -> Path:
        candidates = [Path(text)]
        if not Path(text).is_absolute():
            candidates = [self.root / text, self.root / "decks" / text, self.workspace / text]
        for candidate in candidates:
            if candidate.is_file():
                return candidate.resolve()
        pool = [self.spoken(p) for folder in (self.root / "decks", self.workspace) if folder.is_dir()
                for p in folder.rglob("*.deck")]
        near = difflib.get_close_matches(Path(text).name, [Path(p).name for p in pool], n=3)
        suggestions = [p for p in pool if Path(p).name in near]
        raise refusal(tool, "deck", f"deck file not found: '{text}'", path=text,
                      tried=[self.spoken(c) for c in candidates], suggestions=suggestions[:5])

    def tool_read_deck(self, args: dict) -> dict:
        path = self.find_deck(str(args["deck"]), "read_deck")
        text = path.read_text(encoding="utf-8", errors="replace")
        out: dict = {"file": self.spoken(path), "text": text}
        if path.suffix.lower() == ".dck":
            out["format"] = "dck"
            return out
        out["format"] = "deck"
        out.update(parse_deck(text))
        return out

    def tool_write_deck(self, args: dict) -> dict:
        tool = "write_deck"
        file = str(args["file"])
        if not file.lower().endswith((".deck", ".dec")):
            raise refusal(tool, "option", "`file` ends in .deck (or .dec)", flag="file", path=file)
        path = Path(file)
        if not path.is_absolute() and len(path.parts) == 1:
            path = self.workspace / path
        target = self.inside(str(path), tool, "file")
        if target.exists() and not args.get("force"):
            raise refusal(tool, "out", f"{self.spoken(target)} is there — `force` overwrites it",
                          exit_code=1, path=self.spoken(target))
        main = deck_rows(args["cards"], tool, "cards")
        side = deck_rows(args.get("sideboard") or [], tool, "sideboard")
        if not main:
            raise refusal(tool, "option", "`cards` holds no rows", flag="cards")
        name = str(args.get("name") or target.stem)
        if len(name.splitlines()) != 1 or "\0" in name:
            raise refusal(tool, "option", "`name` must be a single line", flag="name")
        target.parent.mkdir(parents=True, exist_ok=True)
        # Exclusive creation keeps force=false true even if another writer
        # creates the file between the existence check and this open.
        try:
            with target.open("w" if args.get("force") else "x", encoding="utf-8") as stream:
                stream.write(deck_text(name, main, side))
        except OSError as exc:
            raise refusal(tool, "out", f"could not write deck: {exc}", exit_code=1, path=self.spoken(target))
        out: dict = {"file": self.spoken(target), "name": name,
                     "cards": sum(r["count"] for r in main), "sideboard": sum(r["count"] for r in side)}
        if args.get("check", True):
            check = self.quote("check", self.run("check", self.check_args(args, [str(target)])), require_json=True)
            out["check"] = check
            if isinstance(check, dict):
                out["playable"] = check.get("playable")
        return out

    # ----- the AutoDeck and the Lab ---------------------------------------

    def output_args(self, argv: list[str], tool: str) -> tuple[list[str], Path | None]:
        """Check EVERY write destination, including repeated/raw/extra flags.

        Normalise --flag=value to the CLI's two-argument spelling. The last
        --out is the actual destination, not the first or a structured default.
        """
        checked = []
        out = None
        index = 0
        while index < len(argv):
            arg = argv[index]
            flag, equal, inline = arg.partition("=")
            if flag not in ("--out", "--resume", "--elo-file"):
                checked.append(arg)
                index += 1
                continue
            if equal:
                value = inline
            else:
                index += 1
                if index >= len(argv) or argv[index].startswith("--"):
                    raise refusal(tool, "option", f"{flag} needs a path", flag=flag)
                value = argv[index]
            path = self.inside(value, tool, flag)
            checked.extend([flag, str(path)])
            if flag in ("--out", "--resume"):
                out = path
            index += 1
        return checked, out

    @staticmethod
    def flag(argv: list[str], args: dict, key: str, flag: str) -> None:
        value = args.get(key)
        if value is None or value is False or value == "":
            return
        if value is True:
            argv.append(flag)
        else:
            argv += [flag, str(value)]

    def tool_autodeck(self, args: dict) -> dict:
        tool = "autodeck"
        out = self.inside(args["out"], tool, "out")
        argv = ["--out", str(out)]
        args = {**args, "keep": self.deck_arg(args["keep"])} if args.get("keep") else args
        for key in ("count", "seed", "colors", "max_colors", "sets", "source", "packs", "size",
                    "lean", "speed", "gold", "rarity", "variety", "distinct", "keep", "vary"):
            self.flag(argv, args, key, "--" + key.replace("_", "-"))
        self.flag(argv, args, "force", "--force")
        self.flag(argv, args, "dry_run", "--dry-run")
        argv += self.strings(args["extra_args"], tool, "extra_args") if args.get("extra_args") else []
        argv.append("--quiet")
        argv, out = self.output_args(argv, tool)
        timeout = float(args.get("timeout") or DEFAULT_TIMEOUT)
        done = self.run("autodeck", argv, timeout=timeout)
        parsed = self.quote("autodeck", done, require_json="--dry-run" in argv)
        if "--dry-run" in argv:
            return {"plan": parsed, "argv": argv}
        result: dict = {"exit": done.returncode, "out": self.spoken(out), "argv": argv}
        run_file = out / "run.json"
        if run_file.is_file():
            result["run"] = self.read_json(run_file, tool)
            result["next"] = result["run"].get("next")
        listing = out / "decklist.txt"
        if listing.is_file():
            decks = [line.strip() for line in listing.read_text(encoding="utf-8").splitlines()
                     if line.strip() and not line.startswith("#")]
            result["decks"] = [self.spoken((listing.parent / d).resolve()) for d in decks]
            result["count"] = len(decks)
        return result

    LAB_FLAGS = ("deck_a", "deck_b", "gauntlet", "matrix", "field", "deck_pool", "group", "games",
                 "seed", "jobs", "procs", "packs", "profile_a", "profile_b", "top", "best_of",
                 "sideboard", "rules", "format", "lives", "mulligan", "sweep", "null",
                 "control_deck_a", "control_deck_b", "record", "record_max")
    LAB_DECKS = ("deck_a", "deck_b", "deck_pool", "control_deck_a", "control_deck_b")
    LAB_DECK_LISTS = ("gauntlet", "matrix", "field")

    def lab_argv(self, args: dict) -> tuple[list[str], Path | None]:
        tool = "lab"
        if args.get("argv"):
            argv = self.strings(args["argv"], tool, "argv")
            argv, out = self.output_args(argv, tool)
            if "--resume" not in argv and not args.get("rated") and "--no-elo" not in argv:
                argv.append("--no-elo")
            if args.get("dry_run") and "--dry-run" not in argv:
                argv.append("--dry-run")
            if out is None and "--resume" not in argv:
                out = self.default_out(tool)
                argv += ["--out", str(out)]
            return argv + ["--quiet"], out
        argv: list[str] = []
        args = dict(args)
        for key in self.LAB_DECKS:
            if args.get(key):
                args[key] = self.deck_arg(args[key])
        for key in self.LAB_DECK_LISTS:
            if args.get(key):
                args[key] = self.deck_list(args[key])
        for key in self.LAB_FLAGS:
            self.flag(argv, args, key, "--" + key.replace("_", "-"))
        out = None
        if args.get("out"):
            out = self.inside(args["out"], tool, "out")
            argv += ["--out", str(out)]
        if not args.get("rated"):
            argv.append("--no-elo")
        self.flag(argv, args, "dry_run", "--dry-run")
        if args.get("extra_args"):
            argv += self.strings(args["extra_args"], tool, "extra_args")
        argv, actual_out = self.output_args(argv, tool)
        out = actual_out or out
        # A run the client named no folder for goes to the workspace
        # (2026-10-03). It used to go to the Lab's own default under
        # DeckLab/results/, and the answer then lacked `run`, `results`
        # and `next`: the folder was looked for on stderr, while the Lab
        # names it on stdout.
        if out is None and "--resume" not in argv:
            out = self.default_out(tool)
            argv += ["--out", str(out)]
        return argv + ["--quiet"], out

    def run_lab(self, argv: list[str], out: Path | None, args: dict) -> dict:
        timeout = float(args.get("timeout") or DEFAULT_TIMEOUT)
        reporter = self.progress_reporter() if "--dry-run" not in argv else None
        if reporter is not None and "--progress" not in argv:
            # The Lab's machine-readable heartbeat (one JSON line a second on
            # stderr); an explicit `--progress` beats the off `--quiet` implies.
            argv = argv + ["--progress", "json"]
        done = self.run("lab", argv, timeout=timeout, on_stderr=reporter)
        if "--dry-run" in argv:
            return {"plan": self.quote("lab", done, require_json=True), "argv": argv}
        parsed = self.quote("lab", done, ok=(0, 4))
        result: dict = {"exit": done.returncode, "argv": argv, "report": done.stdout}
        if done.returncode == 4:
            result["warning"] = "the control pair did not replay game for game — the results are suspect"
        if out is None:
            out = self.out_from_output(done.stdout, done.stderr)
        if out is not None:
            result.update(self.read_run(out, int(args.get("limit") or RESULT_LIMIT)))
        elif isinstance(parsed, dict):
            result["stdout"] = parsed
        return result

    def out_from_output(self, *texts: str) -> Path | None:
        """The folder a run wrote when its line named none (a raw line
        that resumes, an older recorded `next.argv`): the Lab's last stdout
        line names it — `wrote DIR/{report.txt, ...}`."""
        for text in texts:
            for found in reversed(re.findall(r"^wrote (.+?)/\{", text or "", re.MULTILINE)):
                path = Path(found.strip().strip("'\""))
                path = (path if path.is_absolute() else self.root / path).resolve()
                if (path / "run.json").is_file():
                    return path
        return None

    def tool_lab(self, args: dict) -> dict:
        argv, out = self.lab_argv(args)
        return self.run_lab(argv, out, args)

    def tool_lab_resume(self, args: dict) -> dict:
        out = self.inside(args["out"], "lab", "out")
        return self.run_lab(["--resume", str(out), "--quiet"], out, args)

    def read_run(self, out: Path, limit: int) -> dict:
        result: dict = {"out": self.spoken(out)}
        run_file = out / "run.json"
        if not run_file.is_file():
            raise refusal("read_run", "resume", f"no run.json in {self.spoken(out)}", path=self.spoken(out))
        run = self.read_json(run_file, "read_run")
        result["run"] = run
        result["next"] = run.get("next")
        for name in ("results.json", "sweep.json"):
            path = out / name
            if path.is_file():
                data = self.read_json(path, "read_run")
                if isinstance(data, dict):
                    for key in ("matchups", "standings"):
                        rows = data.get(key)
                        if isinstance(rows, list) and len(rows) > limit:
                            data[key] = rows[:limit]
                            data[key + "_total"] = len(rows)
                            data["truncated"] = True
                result[name.split(".")[0]] = data
        if "report" not in result:
            report = out / "report.txt"
            if report.is_file():
                result["report"] = report.read_text(encoding="utf-8", errors="replace")
        result["files"] = sorted(self.spoken(p) for p in out.iterdir())
        return result

    def tool_read_run(self, args: dict) -> dict:
        out = self.inside(args["out"], "read_run", "out")
        if not out.is_dir():
            raise refusal("read_run", "path", f"not a folder: {args['out']}", path=str(args["out"]))
        return self.read_run(out, int(args.get("limit") or RESULT_LIMIT))

    def tool_lab_next(self, args: dict) -> dict:
        out = self.inside(args["out"], "lab_next", "out")
        run_file = out / "run.json"
        if not run_file.is_file():
            raise refusal("lab_next", "resume", f"no run.json in {self.spoken(out)}", path=self.spoken(out))
        run = self.read_json(run_file, "lab_next")
        nxt = run.get("next")
        if not isinstance(nxt, dict) or not nxt.get("argv"):
            return {"out": self.spoken(out), "next": None,
                    "why": "nothing is open — every matchup decided, every delta clear"}
        argv, target = self.output_args(self.strings(nxt["argv"], "lab_next", "argv"), "lab_next")
        result = self.run_lab(argv + ["--quiet"], target, args)
        result["why"] = nxt.get("why")
        result["from"] = self.spoken(out)
        return result

    # ----- the referee ----------------------------------------------------

    def claim_game(self) -> str:
        """The next game id, claimed on disk (2026-10-03): the folder is
        read again and the game's stderr file is created exclusively, so
        two servers sharing one workspace — the second started before the
        first opened a game — can no longer both number a game `g1` and
        write over each other's record and transcript."""
        folder = self.workspace / "games"
        folder.mkdir(parents=True, exist_ok=True)
        number = self.next_game
        for path in folder.iterdir():
            found = re.match(r"g(\d+)\.", path.name)
            if found:
                number = max(number, int(found.group(1)) + 1)
        while True:
            ident = f"g{number}"
            number += 1
            if ident in self.games:
                continue
            try:
                with (folder / f"{ident}.stderr").open("x", encoding="utf-8"):
                    pass
            except FileExistsError:
                continue
            self.next_game = number
            return ident

    def new_game(self, argv: list[str], view: str, keep: bool = False) -> Game:
        ident = self.claim_game()
        folder = self.workspace / "games"
        stderr = folder / f"{ident}.stderr"
        if not keep:
            game = Game(ident, self.command("referee", argv), view, self.root, stderr,
                        cancelled=self.is_cancelled)
            self.games[ident] = game
            return game
        folder.mkdir(parents=True, exist_ok=True)
        record = {"game": ident, "argv": argv, "view": view, "keep": str(folder / f"{ident}.keep.json"),
                  "lines": str(folder / f"{ident}.lines"), "stderr": str(stderr), "started": time.time()}
        for stale in (Path(record["keep"]), Path(record["lines"])):
            try:
                stale.unlink()
            except OSError:
                pass
        full = self.command("referee", argv + ["--listen", record["keep"], "--idle", str(KEEP_IDLE)])
        record["command"] = full
        game = Game(ident, full, view, self.root, stderr, keep=record, cancelled=self.is_cancelled)
        (folder / f"{ident}.json").write_text(json.dumps(record, indent=1), encoding="utf-8")
        self.games[ident] = game
        return game

    def open_game(self, argv: list[str], view: str, timeout: float, keep: bool = False,
                  until_table: bool = False) -> dict:
        game = self.new_game(argv, view, keep)
        state = game.advance(timeout, until_table=until_table)
        if game.error is not None and game.hello is None:
            game.close(grace=2)
            del self.games[game.ident]
            self.forget_kept(game.ident)
            raise ToolError(game.error)
        state["hello"] = game.hello
        self.settle(game)
        return state

    def settle(self, game: Game) -> None:
        """A game whose result or error is in: the pipe is closed and a
        kept game's record is dropped (its transcript stays)."""
        if game.result is not None or game.error is not None:
            game.close(grace=5)
            if game.kept:
                self.forget_kept(game.ident)

    # ----- kept games: the records under workspace/games ------------------

    def kept_records(self) -> list[dict]:
        folder = self.workspace / "games"
        out = []
        for path in sorted(folder.glob("g*.json")) if folder.is_dir() else []:
            if path.name.endswith(".keep.json"):
                continue
            try:
                record = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                continue
            if isinstance(record, dict) and record.get("game") == path.stem and record.get("keep"):
                out.append(record)
        return out

    def kept_record(self, ident: str) -> dict | None:
        for record in self.kept_records():
            if record.get("game") == ident:
                return record
        return None

    def forget_kept(self, ident: str) -> None:
        folder = self.workspace / "games"
        for name in (f"{ident}.json", f"{ident}.keep.json"):
            try:
                (folder / name).unlink()
            except OSError:
                pass

    TRANSCRIPT_TAIL = 262144
    TRANSCRIPT_LINES = 8

    @staticmethod
    def transcript_result(record: dict) -> dict | None:
        """The result line of a kept game's transcript, if the referee
        wrote one (it ends the game when no client comes back). The result
        — or the error envelope of a referee that could not start — is the
        LAST line a referee writes, so only the transcript's tail is read
        (2026-10-03): `status` and `referee_resume {}` used to parse every
        decision line of every kept game, the whole view each time, on
        every call."""
        try:
            with Path(record["lines"]).open("rb") as stream:
                stream.seek(0, os.SEEK_END)
                size = stream.tell()
                start = max(0, size - Server.TRANSCRIPT_TAIL)
                stream.seek(start)
                tail = stream.read().decode("utf-8", errors="replace")
        except (OSError, KeyError, TypeError):
            return None
        lines = tail.splitlines()
        if start > 0 and lines:
            lines = lines[1:]   # the first line of a tail may be cut
        lines = [line for line in lines if line.strip()][-Server.TRANSCRIPT_LINES:]
        for line in reversed(lines):
            try:
                parsed = json.loads(line)
            except ValueError:
                continue
            if isinstance(parsed, dict) and parsed.get("type") == "result":
                return parsed
            if isinstance(parsed, dict) and "error" in parsed:
                return {"type": "result", "error": parsed["error"]}
        return None

    def kept_summary(self, record: dict) -> dict:
        out = {"game": record.get("game"), "argv": record.get("argv"), "view": record.get("view"),
               "started": record.get("started"), "lines": record.get("lines")}
        result = self.transcript_result(record)
        if result is not None:
            out["result"] = result
        else:
            out["note"] = "referee_resume takes it up"
        return out

    def tool_referee_resume(self, args: dict) -> dict:
        ident = str(args.get("game") or "")
        if not ident:
            return {"kept": [self.kept_summary(r) for r in self.kept_records() if r.get("game") not in self.games],
                    "games": [g.summary() for g in self.games.values()]}
        if ident in self.games:
            return self.tool_referee_wait(args)
        record = self.kept_record(ident)
        if record is None:
            raise refusal("referee", "game", f"no kept game {ident}", game=ident,
                          kept=[r.get("game") for r in self.kept_records()], games=sorted(self.games))
        done = self.transcript_result(record)
        if done is not None:
            self.forget_kept(ident)
            out = {"game": ident, "result": done, "lines": record.get("lines")}
            if "error" in done:
                out["error"] = done["error"]
            return out
        view = self.view_of(args, str(record.get("view") or "brief"))
        game = Game(ident, list(record.get("command") or []), view, self.root,
                    Path(record.get("stderr") or self.workspace / "games" / f"{ident}.stderr"),
                    keep=record, resume=True, cancelled=self.is_cancelled)
        self.games[ident] = game
        state = game.advance(float(args.get("timeout") or 30))
        if game.error is not None and game.hello is None:
            game.close(grace=1)
            del self.games[ident]
            done = self.transcript_result(record)
            # A referee that is not there any more is not coming back:
            # the record goes, the transcript stays for the reader.
            self.forget_kept(ident)
            if done is not None:
                return {"game": ident, "result": done, "lines": record.get("lines")}
            raise ToolError({**game.error, "game": ident, "lines": record.get("lines"),
                             "note": "the kept referee is gone; its transcript is the last word"})
        state["hello"] = game.hello
        state["resumed"] = True
        self.settle(game)
        return state

    @staticmethod
    def view_of(args: dict, fallback: str = "brief") -> str:
        view = args.get("view") or fallback
        if view not in VIEWS:
            raise refusal("referee", "option", f"`view` is one of {', '.join(VIEWS)}", flag="view",
                          suggestions=difflib.get_close_matches(str(view), VIEWS, n=2))
        return view

    def tool_referee_start(self, args: dict) -> dict:
        tool = "referee"
        argv = ["--deck-a", self.deck_arg(args["deck_a"]), "--deck-b", self.deck_arg(args["deck_b"])]
        for key in ("seat_a", "seat_b"):
            if args.get(key):
                if args[key] not in SEATS:
                    raise refusal(tool, "option", f"`{key}` is one of {', '.join(SEATS)}", flag=key,
                                  suggestions=difflib.get_close_matches(str(args[key]), SEATS, n=2))
                argv += ["--" + key.replace("_", "-"), args[key]]
        for key in ("seed", "turns", "packs"):
            self.flag(argv, args, key, "--" + key)
        if args.get("log"):
            argv += ["--log", str(self.inside(args["log"], tool, "log"))]
        return self.open_game(argv, self.view_of(args), float(args.get("timeout") or DECISION_TIMEOUT),
                              keep=bool(args.get("keep", False)))

    def tool_referee_join(self, args: dict) -> dict:
        tool = "referee"
        invitation = args.get("invitation")
        table = args.get("table")
        if not invitation and not table:
            raise refusal(tool, "option", "`invitation` (the host's invitation or access code) or `table` "
                          "(an open table's name on the LAN) names the table to join", flag="invitation")
        if invitation and table:
            raise refusal(tool, "option", "`invitation` and `table` are two ways to name one table — give one",
                          flag="table")
        argv = (["--join", str(invitation)] if invitation else ["--table", str(table)]) + ["--deck", self.deck_arg(args["deck"])]
        for key in ("port", "name", "wait", "turns", "packs"):
            self.flag(argv, args, key, "--" + key)
        if args.get("log"):
            argv += ["--log", str(self.inside(args["log"], tool, "log"))]
        return self.open_game(argv, self.view_of(args), float(args.get("timeout") or 15),
                              keep=bool(args.get("keep", True)))

    def tool_referee_host(self, args: dict) -> dict:
        tool = "referee"
        argv = ["--host", str(args["table"]), "--deck", self.deck_arg(args["deck"])]
        for key in ("access", "name", "port", "address", "wait", "turns", "packs"):
            self.flag(argv, args, key, "--" + key)
        if args.get("log"):
            argv += ["--log", str(self.inside(args["log"], tool, "log"))]
        state = self.open_game(argv, self.view_of(args), float(args.get("timeout") or 15),
                               keep=bool(args.get("keep", True)), until_table=True)
        table = state.get("table")
        if table and state.get("pending"):
            name = table.get("name")
            if table.get("access") == "invitation":
                state["note"] = (f"the table '{name}' is open at {table.get('address')}:{table.get('port')} "
                                 "for the person who pastes its `invitation` into the game's Join screen; "
                                 "hand them the invitation, then `referee_wait` until they sit down")
            else:
                state["note"] = (f"the table '{name}' is listed in every Game Browser on the LAN"
                                 + ("" if table.get("discovery") else
                                    " — except that the advert could not go out (the discovery port is "
                                    "busy): hand them the `invitation` to paste instead")
                                 + f"; the person joins it by name (host '{table.get('host')}'), "
                                 "then `referee_wait` until they sit down")
        return state

    def game_of(self, args: dict) -> Game:
        ident = str(args["game"])
        game = self.games.get(ident)
        if game is None:
            raise refusal("referee", "game", f"no game {ident}", game=ident,
                          games=sorted(self.games))
        return game

    def tool_referee_act(self, args: dict) -> dict:
        game = self.game_of(args)
        if game.result is not None or game.error is not None:
            return game.summary()
        if game.pending is None:
            raise refusal("referee", "game", f"game {game.ident} has no decision pending — referee_wait reads on",
                          game=game.ident)
        if args.get("view"):
            game.view = self.view_of(args)
        action = args["action"]
        if action == "default":
            action = default_answer(game.pending, game.memory)
        if not isinstance(action, dict) or "op" not in action:
            raise refusal("referee", "option", "`action` is an object with `op`, or `default`", flag="action")
        action = dict(action)
        action.setdefault("seat", game.pending.get("seat"))
        until = args.get("until")
        if until is not None and until not in UNTIL:
            raise refusal("referee", "option", f"`until` is one of {', '.join(UNTIL)}", flag="until",
                          suggestions=difflib.get_close_matches(str(until), UNTIL, n=2))
        timeout = float(args.get("timeout") or DECISION_TIMEOUT)
        origin = game.pending
        game.send(action)
        if until is None:
            state = game.advance(timeout)
        else:
            state = self.pass_until(game, str(until), origin, timeout)
        state["action"] = action
        self.settle(game)
        return state

    def pass_until(self, game: Game, until: str, origin: dict, timeout: float) -> dict:
        """After the client's own answer: pass priority for it until
        `stop_reason` names a place a player would act, the result, an
        error, a refusal, a timeout or MAX_PASSES. The journal of every
        decision passed over is kept for the one shown."""
        passed = 0
        refused: list[dict] = []
        while True:
            state = game.advance(timeout, render=False)
            refused += state.get("refused", [])
            if state.get("pending") or game.pending is None or refused:
                break
            reason = stop_reason(game.pending, until, origin)
            if reason:
                state["stop"] = reason
                break
            if passed >= MAX_PASSES:
                state["stop"] = f"{MAX_PASSES} decisions passed and `{until}` was not reached"
                break
            game.passed_journal += list((game.pending.get("view") or {}).get("journal") or [])
            game.send({"op": "pass", "seat": game.pending.get("seat")})
            passed += 1
        if game.pending is not None and "decision" not in state and not state.get("pending"):
            state["decision"] = game.shown()
        state["passed"] = passed
        state["until"] = until
        if refused:
            state["refused"] = refused
            state["stop"] = "an answer was refused"
        return state

    def tool_referee_autoplay(self, args: dict) -> dict:
        game = self.game_of(args)
        if args.get("view"):
            game.view = self.view_of(args)
        limit = int(args["decisions"]) if args.get("decisions") else None
        timeout = float(args.get("timeout") or DECISION_TIMEOUT)
        played = 0
        refused: list[dict] = []
        state = game._state([], pending=game.pending is None and game.result is None and game.error is None)
        while game.pending is not None and game.result is None and game.error is None:
            if limit is not None and played >= limit:
                break
            action = default_answer(game.pending, game.memory)
            action.setdefault("seat", game.pending.get("seat"))
            game.send(action)
            state = game.advance(timeout)
            played += 1
            refused += state.get("refused", [])
            if state.get("pending"):
                break
        state["played"] = played
        if refused:
            state["refused"] = refused
        self.settle(game)
        return state

    def tool_referee_wait(self, args: dict) -> dict:
        game = self.game_of(args)
        if args.get("view"):
            game.view = self.view_of(args)
        if game.pending is not None or game.result is not None or game.error is not None:
            state = game._state([])
            state["hello"] = game.hello
            return state
        state = game.advance(float(args.get("timeout") or DECISION_TIMEOUT))
        state["hello"] = game.hello
        self.settle(game)
        return state

    def tool_referee_stop(self, args: dict) -> dict:
        game = self.game_of(args)
        if game.running and game.kept:
            # A kept referee reads no end-of-input: the seat concedes.
            # With no decision pending the line waits in the socket for
            # the next one.
            concede: dict = {"op": "concede"}
            if game.pending is not None:
                concede["seat"] = game.pending.get("seat")
            try:
                game.send(concede)
            except ToolError:
                pass
            game.advance(10)
        elif game.running:
            game.close(grace=1)
            game.advance(10)
        game.close(grace=10)
        if game.kept and game.result is not None:
            self.forget_kept(game.ident)
        return game.summary()

    def shutdown(self) -> None:
        """Games on a pipe end with the server; kept games are let go —
        their referee listens on, `referee_resume` finds them again. A door
        child still running (a call cut short) is stopped with its group."""
        with self.flight_lock:
            children = list(self.children)
        for proc in children:
            stop_tree(proc)
        for game in list(self.games.values()):
            if game.kept and game.result is None and game.error is None:
                game.detach()
            else:
                game.close(grace=5)

    # ----- the protocol -----------------------------------------------------

    def resources(self) -> list[dict]:
        rows = [{"uri": "shandalar://contract", "name": CONTRACT, "mimeType": "text/markdown",
                 "description": "the contract page for every command-line tool"},
                {"uri": "shandalar://play-guide", "name": PLAY_GUIDE, "mimeType": "text/markdown",
                 "description": "MTG rules, fair-information play, combat and deck-building strategy"}]
        rows += [{"uri": f"shandalar://manual/{verb}", "name": f"manual {verb}", "mimeType": "text/plain",
                  "description": f"the `--help` of the {verb} tool"} for verb in MANUALS]
        return rows

    def read_resource(self, uri: str) -> dict:
        if uri == "shandalar://contract":
            page = self.tool_contract({})
            return {"uri": uri, "mimeType": "text/markdown", "text": page["text"]}
        if uri == "shandalar://play-guide":
            page = self.tool_play_guide({})
            return {"uri": uri, "mimeType": "text/markdown", "text": page["text"]}
        found = re.fullmatch(r"shandalar://manual/([a-z]+)", uri or "")
        if found and found.group(1) in MANUALS:
            page = self.tool_manual({"verb": found.group(1)})
            return {"uri": uri, "mimeType": "text/plain", "text": page["text"]}
        raise UnknownResource(uri)

    def handle(self, message) -> dict | None:
        if (not isinstance(message, dict) or message.get("jsonrpc") != "2.0"
                or not isinstance(message.get("method"), str)
                or isinstance(message.get("id"), (bool, dict, list))):
            ident = message.get("id") if isinstance(message, dict) else None
            if isinstance(ident, (bool, dict, list)):
                ident = None
            return error_response(ident, -32600, "Invalid Request")
        method = message["method"]
        ident = message.get("id")
        params = message.get("params") or {}
        notification = "id" not in message
        try:
            if method == "initialize":
                asked = params.get("protocolVersion") if isinstance(params, dict) else None
                version = asked if asked in PROTOCOL_VERSIONS else LATEST_PROTOCOL
                result = {"protocolVersion": version,
                          "capabilities": {"tools": {"listChanged": False}, "resources": {"subscribe": False, "listChanged": False}},
                          "serverInfo": {"name": SERVER_NAME, "title": "Shandalar", "version": self.version() or "unknown"},
                          "instructions": INSTRUCTIONS}
            elif method == "ping":
                result = {}
            elif method == "tools/list":
                result = {"tools": self.listing()}
            elif method == "tools/call":
                name = params.get("name") if isinstance(params, dict) else None
                if not isinstance(name, str):
                    return None if notification else error_response(ident, -32602, "tools/call needs a tool name")
                try:
                    payload = self.call(name, params.get("arguments"))
                    result = tool_result(payload, False)
                except UnknownTool as exc:
                    return None if notification else error_response(
                        ident, -32602, f"unknown tool '{name}'", {"suggestions": exc.near, "tools": [t["name"] for t in self.tools]})
                except ToolError as exc:
                    result = tool_result({"error": exc.envelope}, True)
            elif method == "resources/list":
                result = {"resources": self.resources()}
            elif method == "resources/read":
                uri = params.get("uri") if isinstance(params, dict) else None
                try:
                    result = {"contents": [self.read_resource(str(uri))]}
                except UnknownResource:
                    return None if notification else error_response(ident, -32002, f"unknown resource '{uri}'")
                except ToolError as exc:
                    return None if notification else error_response(ident, -32603, exc.envelope.get("message", "refused"))
            elif method.startswith("notifications/"):
                return None
            else:
                return None if notification else error_response(ident, -32601, f"Method not found: {method}")
        except Cancelled as exc:
            # MCP: a cancelled request is not answered.
            print(f"shandalar_mcp: {method}: cancelled ({exc})", file=sys.stderr)
            return None
        except Exception as exc:  # noqa: BLE001 — the protocol answer is the report
            print(f"shandalar_mcp: {method}: {type(exc).__name__}: {exc}", file=sys.stderr)
            return None if notification else error_response(ident, -32603, f"{type(exc).__name__}: {exc}")
        if notification:
            return None
        return {"jsonrpc": "2.0", "id": ident, "result": result}

    def serve(self, source=None, sink=None) -> int:
        """Read the client's lines until end of input. Requests are
        answered in order, one at a time, on a worker thread; this thread
        answers a `ping` at once and applies `notifications/cancelled` to
        the call in flight (or to a call still queued) while the worker is
        busy. At end of input every request already read is still answered
        — a client may pipe a file of requests — and then the games end."""
        source = source or sys.stdin
        sink = sink or sys.stdout
        self.sink = sink
        work: queue.Queue = queue.Queue()
        worker = threading.Thread(target=self._work, args=(work, sink), name="mcp-worker", daemon=True)
        worker.start()
        try:
            for raw in source:
                line = raw.strip()
                if not line:
                    continue
                try:
                    message = json.loads(line)
                except ValueError:
                    self.emit(sink, error_response(None, -32700, "Parse error"))
                    continue
                if isinstance(message, list) and not message:
                    self.emit(sink, error_response(None, -32600, "Invalid Request"))
                    continue
                if isinstance(message, dict) and self._urgent(message, sink):
                    continue
                work.put(message)
        finally:
            if self.stopping:
                self.cancel_all(work)
            work.put(None)
            while worker.is_alive():
                worker.join(0.25)
            self.shutdown()
        return 0

    def _urgent(self, message: dict, sink) -> bool:
        """What the reader thread answers itself rather than queueing:
        `ping` (a liveness probe must not wait behind a Lab run) and
        `notifications/cancelled`. True when the message was handled."""
        method = message.get("method")
        if message.get("jsonrpc") != "2.0":
            return False
        if method == "ping" and "id" in message and not isinstance(message.get("id"), (bool, dict, list)):
            self.emit(sink, {"jsonrpc": "2.0", "id": message["id"], "result": {}})
            return True
        if method == "notifications/cancelled" and "id" not in message:
            params = message.get("params")
            target = params.get("requestId") if isinstance(params, dict) else None
            if target is not None and not isinstance(target, (bool, dict, list)):
                with self.flight_lock:
                    if self.flight_id is not None and self.flight_id == target:
                        self.flight_cancel.set()
                    else:
                        self.cancelled_ids.add(json.dumps(target))
            return True
        return False

    def _work(self, work: queue.Queue, sink) -> None:
        while True:
            message = work.get()
            if message is None:
                return
            if isinstance(message, list):
                answers = [a for a in (self._dispatch(m) for m in message) if a is not None]
                if answers:
                    self.emit(sink, answers)
                continue
            answer = self._dispatch(message)
            if answer is not None:
                self.emit(sink, answer)

    def _dispatch(self, message) -> dict | None:
        """One message through `handle`, as the call in flight: a request
        cancelled while it waited is skipped, one cancelled while it ran is
        not answered."""
        ident = message.get("id") if isinstance(message, dict) else None
        key = json.dumps(ident) if ident is not None and not isinstance(ident, (dict, list)) else None
        with self.flight_lock:
            if key is not None and key in self.cancelled_ids:
                self.cancelled_ids.discard(key)
                return None
            self.flight_id = ident if key is not None else None
            self.flight_cancel = threading.Event()
            self.flight_progress = progress_token(message)
            cancel = self.flight_cancel
        try:
            answer = self.handle(message)
        finally:
            with self.flight_lock:
                self.flight_id = None
                self.flight_progress = None
        return None if cancel.is_set() else answer

    def cancel_all(self, work: queue.Queue | None = None) -> None:
        """Stop the call in flight and drop what is queued: the server is
        going away (a SIGTERM from the client)."""
        self.stopping = True
        with self.flight_lock:
            self.flight_cancel.set()
        while work is not None:
            try:
                work.get_nowait()
            except queue.Empty:
                break

    def emit(self, sink, message) -> None:
        with self.write_lock:
            emit(sink, message)


def progress_token(message) -> str | int | None:
    """A request's `params._meta.progressToken` (MCP: a string or an
    integer), or None."""
    params = message.get("params") if isinstance(message, dict) else None
    meta = params.get("_meta") if isinstance(params, dict) else None
    token = meta.get("progressToken") if isinstance(meta, dict) else None
    if isinstance(token, bool) or not isinstance(token, (str, int)):
        return None
    return token


def tool_result(payload: dict, is_error: bool) -> dict:
    text = json.dumps(payload, ensure_ascii=False, default=str)
    return {"content": [{"type": "text", "text": text}], "structuredContent": payload, "isError": is_error}


def error_response(ident, code: int, message: str, data=None) -> dict:
    error: dict = {"code": code, "message": message}
    if data is not None:
        error["data"] = data
    return {"jsonrpc": "2.0", "id": ident, "error": error}


def emit(sink, message) -> None:
    sink.write(json.dumps(message, ensure_ascii=False, default=str) + "\n")
    sink.flush()


def find_door(spoken: str | None) -> Path:
    if spoken:
        door = Path(spoken)
        if not door.is_file():
            print(f"shandalar_mcp: no door at {door}", file=sys.stderr)
            sys.exit(2)
        return door
    here = Path(__file__).resolve().parent
    names = (WINDOWS_DOOR, DOOR_NAME) if os.name == "nt" else (DOOR_NAME, WINDOWS_DOOR)
    for folder in (here.parent, here):
        for name in names:
            if (folder / name).is_file():
                return folder / name
    print(f"shandalar_mcp: no {DOOR_NAME} or {WINDOWS_DOOR} beside this script — "
          "extract the whole release folder or give --door", file=sys.stderr)
    sys.exit(2)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="shandalar_mcp.py",
        description="Shandalar's tools as an MCP server on stdio (JSON-RPC 2.0, one message a line).")
    parser.add_argument("--door", help=f"{DOOR_NAME} or {WINDOWS_DOOR} (default: beside this script)")
    parser.add_argument("--workspace", default=WORKSPACE,
                        help=f"where a client's decks and runs go (default: {WORKSPACE}/ beside the door)")
    parser.add_argument("--catalogue", action="store_true",
                        help="print the tool list as JSON and exit (no client needed)")
    parser.add_argument("-V", "--version", action="store_true", help="the version, and exit")
    args = parser.parse_args(argv)
    # MCP stdio is UTF-8 even when a Windows installation's locale is not.
    for stream in (sys.stdin, sys.stdout):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    server = Server(find_door(args.door), Path(args.workspace))
    if args.version:
        print(f"shandalar_mcp.py — Shandalar {server.version() or 'version unknown'}")
        return 0
    if args.catalogue:
        print(json.dumps({"tools": server.listing(), "resources": server.resources()}, indent=1, ensure_ascii=False))
        return 0
    # A client ends a stdio server by closing its input and then, if it
    # lingers, with SIGTERM (2026-10-03). Python's default SIGTERM ends the
    # process at once, without its `finally`: the door child of a call in
    # flight then played on alone — a Lab run for the rest of its games.
    # Now the call is cancelled, its child stopped, and pipe games end.
    def terminate(signum, _frame):
        if server.stopping:
            return
        server.cancel_all()
        raise SystemExit(128 + signum)

    if hasattr(signal, "SIGTERM"):
        try:
            signal.signal(signal.SIGTERM, terminate)
        except ValueError:
            pass   # not the main thread (an embedding host): keep the default
    return server.serve()


if __name__ == "__main__":
    sys.exit(main())
