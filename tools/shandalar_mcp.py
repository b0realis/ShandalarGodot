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
    answers alone, `delta` what moved, and `compact` (2026-10-04) the
    board as a few lines of text that become the answer's `content` —
    what a client shows its model — while `structuredContent` keeps
    the JSON. `until` passes priority for the client (`mine`, the
    smart pass, stops on the opponent's account only while the seat
    holds something usable); `referee_cast` prepares, pays and submits
    in one call and never leaves a cast half-announced.
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

try:
    import decision_menu   # the decision-model menus (0.50.13), shipped beside this script
except ImportError:        # imported from elsewhere: the script's own folder
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import decision_menu

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
VIEWS = ("brief", "full", "options", "delta", "compact")
# `referee_act`'s `until`: the stop the server passes priority toward —
# the seat's own main phase, the end step of this turn, the seat's next
# turn, only a reaction window (`respond`), or the next point the seat
# can act at all (`play`). Every value stops at a reaction window: an
# opponent's spell or ability on the stack, their attack and block
# steps, their end step, a non-priority decision (see `stop_reason`).
# `mine` (2026-10-04, the recommended one) is the SMART pass: the seat's
# own main phase with something to do and its own decisions, and a
# reaction window only while it holds something usable there right now
# (a castable instant or flash spell, a legal non-mana ability) — the
# windows where it holds nothing are passed straight through.
# `mine-strict` never stops on the opponent's account at all.
UNTIL = ("main", "end", "turn", "respond", "play", "mine", "mine-strict")
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
    "your own. Every referee answer's text is the compact table summary (the "
    "board, your hand, the stack, the prompt and the legal answers as a few "
    "lines; the JSON is in structuredContent, rendered per `view`; `text: "
    "\"json\"` on referee_start puts JSON in the text instead). RECOMMENDED: "
    "`view: \"compact\"` for the same text inside the JSON too, "
    "`until: \"mine\"` (pass to your next real decision — the opponent's turn "
    "stops only while you hold something usable there; `mine-strict` never "
    "stops for it), and the one-call `referee_cast` (prepare, pay and submit, "
    "targets by id, name, `me` or `opponent`) and `referee_play_land`; "
    "`referee_view` reads the decision again in any view; `referee_menu` and "
    "`referee_pick` offer a decision model the same game as a numbered menu "
    "of complete legal actions. "
    "`view: \"delta\"` shows only what changed since the last decision. "
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
    shaped like it. `text`, when given, is the answer's `content` (a
    compact-view game's refusal shows its board, see `Answer`)."""

    def __init__(self, envelope: dict, text: str | None = None):
        super().__init__(envelope.get("message", "refused"))
        self.envelope = envelope
        self.text = text


class Answer(dict):
    """A tool's answer whose `content` text is not its JSON: a referee
    answer in the `compact` view (2026-10-04) — an MCP client shows the
    content to its model, so the model reads the board as a few lines of
    text while `structuredContent` keeps the JSON for a program."""

    def __init__(self, payload: dict, text: str):
        super().__init__(payload)
        self.text = text


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


# Every zone of a player's whose cards carry a handle in the view.
CARD_ZONES = ("battlefield", "phased_out", "graveyard", "exile", "revealed", "ante")


def view_cards(view: dict) -> dict:
    """Every card the view names by handle — the hand and both players'
    zones (the phased-out ones too) — as {handle: card}."""
    out: dict = {}
    for card in view.get("hand", []) or []:
        if isinstance(card, dict) and card.get("id"):
            out.setdefault(card["id"], card)
    for player in view.get("players", []) or []:
        if not isinstance(player, dict):
            continue
        for zone in CARD_ZONES:
            for card in player.get(zone, []) or []:
                if isinstance(card, dict) and card.get("id"):
                    out.setdefault(card["id"], card)
    return out


def phase_holds(view: dict) -> dict:
    """The phased-out cards a permanent holds out (Pack 8 — Oubliette,
    Teferi's Imp's kin): {phased handle: holder handle}, from the view's
    `presentation.phase_holds` pairs."""
    out: dict = {}
    for pair in (view.get("presentation") or {}).get("phase_holds", []) or []:
        if isinstance(pair, (list, tuple)) and len(pair) == 2:
            out[str(pair[0])] = str(pair[1])
    return out


def phase_return(card: dict, view: dict, seat: int, controller, cards: dict | None = None,
                 holds: dict | None = None, rows: dict | None = None) -> str:
    """How a phased-out card comes back, as the board's tooltip says it
    (MiniCard.phase_note): with the permanent it is attached to, when the
    card holding it leaves, or at its controller's next untap step —
    "your" or "the opponent's" from this seat's side of the table."""
    cards = view_cards(view) if cards is None else cards
    holds = phase_holds(view) if holds is None else holds
    if rows is None:
        rows = {r.get("id"): r for r in (view.get("presentation") or {}).get("cards", []) if isinstance(r, dict)}
    ident = card.get("id")
    flags = (rows.get(ident) or {}).get("flags") or {}
    host = cards.get(card.get("attached") or "")
    if flags.get("phased_indirectly") and host is not None:
        return f"phases in with {host.get('name', '?')} ({host.get('id')})"
    if ident in holds:
        holder = cards.get(holds[ident]) or {}
        return f"held by {holder.get('name', 'another card')} ({holds[ident]}): phases in when it leaves the battlefield"
    whose = "your" if controller == seat else "the opponent's"
    return f"returns at {whose} next untap step"


def brief_view(view: dict, seat: int) -> dict:
    """The seat's whole LAN view, cut to what a decision needs: whose
    turn, the life totals, both boards (and what is phased out of them),
    this seat's hand with the costs and the castable marks, the stack,
    the new journal lines, and the prompts that are open (announcement,
    choice, damage, discard)."""
    cast = {c.get("id"): c for c in view.get("presentation", {}).get("cards", []) if isinstance(c, dict)}
    cards = view_cards(view)
    holds = phase_holds(view)
    out: dict = {"turn": view.get("turn"), "step": view.get("step"), "active": view.get("active"),
                 "actor": view.get("actor"), "seat": seat}
    players = []

    def board_card(card: dict) -> dict:
        row = brief_card(card, cast.get(card.get("id")), True)
        host = cards.get(card.get("attached") or "")
        if host is not None:
            # An Aura or Equipment: the host's handle (`attached`, the
            # view's own) and its name beside it (2026-10-04).
            row["attached_name"] = host.get("name", "")
        return row

    for player in view.get("players", []):
        row = {"seat": player.get("seat"), "deck": player.get("deck_name", ""),
               "life": player.get("life"), "hand": player.get("hand_count"),
               "library": player.get("library_count"),
               "battlefield": [board_card(c) for c in player.get("battlefield", []) if isinstance(c, dict)]}
        # PHASED OUT (Pack 8, 2026-10-04): off the battlefield every rule
        # reads, still on the table and public to both seats — the brief
        # copied the battlefield alone, and a client was blind to its own
        # phased-out creatures and the opponent's.
        phased = []
        for card in player.get("phased_out", []) or []:
            if isinstance(card, dict):
                gone = board_card(card)
                gone["phased_out"] = True
                gone["returns"] = phase_return(card, view, seat, player.get("seat"), cards, holds, cast)
                phased.append(gone)
        if phased:
            row["phased_out"] = phased
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
        moved = attachment_changes(old.get("battlefield", []), player.get("battlefield", []))
        if moved:
            row["attached_changed"] = moved
        added, gone, changed = card_changes(old.get("phased_out", []), player.get("phased_out", []))
        if added:
            row["phased_out_added"] = added
        if gone:
            row["phased_out_gone"] = gone
        if changed:
            row["phased_out_changed"] = changed
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


def attachment_changes(old: list, new: list) -> list:
    """The Auras and Equipment that stayed on the battlefield but moved —
    attached, unattached or moved to another host — as {id, name, to,
    from}, each end a 'Name (handle)' or None."""
    def host(card: dict):
        if not card.get("attached"):
            return None
        return f"{card.get('attached_name') or '?'} ({card['attached']})"

    old_by = {c.get("id"): c for c in old if isinstance(c, dict)}
    out = []
    for card in new:
        if not isinstance(card, dict) or card.get("id") not in old_by:
            continue
        was = old_by[card["id"]]
        if was.get("attached") != card.get("attached"):
            out.append({"id": card["id"], "name": card.get("name"), "to": host(card), "from": host(was)})
    return out


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
    with what changed since `before` (the last brief shown), `compact`
    replaces it with the brief AND the board as a few lines of text (the
    answer's `content`, see `compact_answer`). `brief` is the decision's
    brief when the caller has already made it."""
    if mode == "full":
        return decision
    out = {k: v for k, v in decision.items() if k != "view"}
    if mode in ("brief", "delta", "compact") and brief is None:
        brief = brief_view(decision.get("view", {}), int(decision.get("seat", 0)))
    if mode == "brief":
        out["brief"] = brief
    elif mode == "delta":
        out["delta"] = delta_view(before, brief)
    elif mode == "compact":
        out["brief"] = brief
        out["compact"] = compact_view(decision)
    return out


# --- the compact view: the board as text a model reads at a glance --------

def _words(step) -> str:
    return str(step or "").lower().replace("_", " ")


def _counters(counters) -> str:
    if isinstance(counters, dict):
        return ", ".join(f"{key} x{value}" for key, value in sorted(counters.items(), key=lambda kv: str(kv[0]))
                         if value)
    return str(counters) if counters else ""


RULES_HINT = 80


def _rules_hint(card: dict) -> str:
    """A card's rules text cut to one short line for the compact view:
    reminder text in parentheses dropped, lines joined, at most
    RULES_HINT characters — enough to know a flyer from a ground pounder;
    the brief view carries the whole text."""
    text = re.sub(r"\s*\([^()]*\)", "", str(card.get("rules") or ""))
    text = "; ".join(part.strip() for part in text.splitlines() if part.strip())
    return text if len(text) <= RULES_HINT else text[:RULES_HINT - 1].rstrip() + "…"


def _named(card: dict | None, ident=None) -> str:
    """`Name c7` — a card as the compact view names it."""
    card = card or {}
    ident = ident if ident is not None else card.get("id", "")
    name = card.get("name") or "?"
    return f"{name} {ident}".strip()


def _permanent(card: dict, cards: dict, seat: int, rows: dict, holds: dict, view: dict,
               controller=None, phased: bool = False) -> str:
    """One permanent: name, handle, P/T, then its state in brackets —
    tapped, summoning sick, attacking, blocking, damage, counters, what
    it is attached to, and for a phased-out card how it comes back."""
    text = _named(card)
    if card.get("creature"):
        text += f" {card.get('power', 0)}/{card.get('toughness', 0)}"
    flags = []
    if card.get("masked"):
        flags.append("face-down")
    if card.get("tapped"):
        flags.append("tapped")
    if card.get("sick") and card.get("creature"):
        flags.append("sick")
    if card.get("attacking"):
        flags.append("attacking")
    if card.get("blocking"):
        flags.append(f"blocking {_named(cards.get(card['blocking']), card['blocking'])}")
    if card.get("damage"):
        flags.append(f"damage {card['damage']}")
    counters = _counters(card.get("counters"))
    if counters:
        flags.append(counters)
    if card.get("attached"):
        flags.append(f"on {_named(cards.get(card['attached']), card['attached'])}")
    if phased:
        flags.append("PHASED OUT, " + phase_return(card, view, seat, controller, cards, holds, rows))
    hint = _rules_hint(card)
    return text + (f" [{'; '.join(flags)}]" if flags else "") + (f" — {hint}" if hint else "")


def _spell_cost(row: dict | None) -> str:
    for ability in (row or {}).get("abilities", []) or []:
        if isinstance(ability, dict) and ability.get("kind") == "spell":
            return str(ability.get("cost") or "")
    return ""


def _target_row(target: dict, refs: dict) -> str:
    """One candidate of an announcement slot: the token, its label, and
    the card or player it is — `t2 Grizzly Bears — opponent's [c9]`."""
    token = target.get("id", "")
    what = target.get("card") or refs.get(token, "")
    return f"{token} {target.get('label', '')}" + (f" [{what}]" if what else "")


def target_refs(view: dict) -> dict:
    """{token: 'c9' | 'player:0' | 'ability:a3' | ...}: what each open
    announcement token stands for — the view's `presentation.targets`
    (each token's reference, built beside the announcement), the handle a
    client already knows the card by."""
    out: dict = {}
    for row in (view.get("presentation") or {}).get("targets", []) or []:
        if not isinstance(row, dict) or not isinstance(row.get("ref"), dict):
            continue
        ref = row["ref"]
        kind, ident = ref.get("kind"), ref.get("id")
        if not ident and ident != 0:
            continue
        out[str(row.get("token"))] = str(ident) if kind == "card" else f"{kind}:{ident}"
    return out


def compact_view(decision: dict) -> str:
    """The decision as a short, deterministic text: the clock, each
    player's life, hand, library and graveyard, both boards with their
    flags (phased-out cards and attachments included), this seat's hand
    with costs and castable marks, the stack, the open prompt with every
    token and option, the legal answers as one line each, and the new
    journal lines. Everything a turn needs, a twentieth of the wire's
    view; `brief` beside it carries the same as JSON."""
    view = decision.get("view") or {}
    options = decision.get("options") or {}
    seat = int(decision.get("seat", 0) or 0)
    mode = str(decision.get("mode") or options.get("mode") or view.get("mode") or "")
    cards = view_cards(view)
    rows = {r.get("id"): r for r in (view.get("presentation") or {}).get("cards", []) if isinstance(r, dict)}
    holds = phase_holds(view)
    whose = "your" if view.get("active") == seat else "the opponent's"
    lines = [f"TURN {view.get('turn', decision.get('turn'))} {view.get('step', decision.get('step'))} — "
             f"{whose} turn | you are seat {seat} | decision #{decision.get('n')}: {mode}"]
    if view.get("winner", -1) not in (-1, None):
        lines.append(f"WINNER: seat {view['winner']}")
    players = sorted([p for p in view.get("players", []) or [] if isinstance(p, dict)],
                     key=lambda p: (p.get("seat") != seat, p.get("seat", 0)))
    for player in players:
        who = "YOU" if player.get("seat") == seat else "OPPONENT"
        head = (f"{who} (seat {player.get('seat')}, {player.get('deck_name') or 'deck'}): "
                f"life {player.get('life')} | hand {player.get('hand_count')} | "
                f"library {player.get('library_count')} | graveyard {len(player.get('graveyard') or [])}")
        pool = player.get("mana_colors") or []
        if player.get("mana"):
            shown = " ".join(f"{c}{n}" for c, n in zip("WUBRGC", pool) if n) if pool else str(player["mana"])
            head += f" | mana pool {shown}"
        lines.append(head)
        lands = [c for c in player.get("battlefield", []) or [] if isinstance(c, dict) and c.get("land")
                 and not c.get("creature") and not c.get("attached")]
        others = [c for c in player.get("battlefield", []) or [] if isinstance(c, dict) and c not in lands]
        if lands:
            lines.append("  lands: " + ", ".join(_named(c) + (" (tapped)" if c.get("tapped") else "") for c in lands))
        for card in others:
            lines.append("  " + _permanent(card, cards, seat, rows, holds, view, player.get("seat")))
        for card in player.get("phased_out", []) or []:
            if isinstance(card, dict):
                lines.append("  " + _permanent(card, cards, seat, rows, holds, view, player.get("seat"), phased=True))
        if not lands and not others and not player.get("phased_out"):
            lines.append("  (no permanents)")
        if player.get("graveyard"):
            lines.append("  graveyard: " + ", ".join(names_of(player["graveyard"])))
        if player.get("exile"):
            lines.append("  exile: " + ", ".join(names_of(player["exile"])))
        if player.get("revealed"):
            lines.append("  revealed hand cards: " + ", ".join(_named(c) for c in player["revealed"] if isinstance(c, dict)))
        if player.get("top"):
            lines.append(f"  library top (revealed): {player['top']}")
    hand = [c for c in view.get("hand", []) or [] if isinstance(c, dict)]
    lines.append(f"YOUR HAND ({len(hand)}):" + ("" if hand else " empty"))
    for card in hand:
        row = rows.get(card.get("id")) or {}
        text = "  " + _named(card)
        if card.get("land"):
            text += " — land" + (", playable now" if card.get("playable") else "")
        else:
            cost = _spell_cost(row)
            if cost:
                text += f" {cost}"
            if row.get("castable"):
                text += " — CASTABLE"
            hint = _rules_hint(card)
            if hint:
                text += f" | {hint}"
        lines.append(text)
    stack = [s for s in view.get("stack", []) or [] if isinstance(s, dict)]
    if stack:
        lines.append("STACK (top first):")
        for i, item in enumerate(reversed(stack), 1):
            owner = "yours" if item.get("controller") == seat else "opponent's"
            text = f"  {i}. {item.get('name', '?')} ({owner}) — {item.get('details', '')}"
            if item.get("x"):
                text += f", X={item['x']}"
            if item.get("targets"):
                text += " -> " + "; ".join(str(t) for t in item["targets"])
            lines.append(text)
    lines.extend(_prompt_lines(view, options, cards, rows))
    lines.extend(_option_lines(mode, options, view, cards, rows))
    journal = [e.get("text", "") if isinstance(e, dict) else str(e) for e in view.get("journal", []) or []]
    if journal:
        lines.append(f"JOURNAL ({len(journal)} new):")
        lines.extend("  " + line for line in journal)
    return "\n".join(lines)


def _prompt_lines(view: dict, options: dict, cards: dict, rows: dict) -> list[str]:
    """The prompt that is open: an announcement's slots with every target
    token, a choice's options with their indexes, a damage assignment,
    a discard, and the information this seat was shown."""
    lines: list[str] = []
    announcement = options.get("announcement") or view.get("announcement") or {}
    if announcement:
        draft = options.get("draft") or (view.get("presentation") or {}).get("draft") or {}
        reach = draft.get("reachable")
        lines.append(f"ANNOUNCING {announcement.get('name', '?')} ({announcement.get('kind', 'spell')}"
                     + (f", X={announcement['x']}" if announcement.get("x") else "") + ")"
                     + ("" if reach is None else f" — the cost {'can' if reach else 'can NOT'} be paid now"))
        refs = target_refs(view)
        for i, slot in enumerate(announcement.get("slots", []) or []):
            span = f"{slot.get('min', 0)}-{slot.get('max', 0)}"
            divided = f", divide {slot['divided']}" if slot.get("divided") else ""
            targets = " | ".join(_target_row(t, refs) for t in slot.get("targets", []) or [] if isinstance(t, dict))
            lines.append(f"  slot {i}: {slot.get('label', 'target')} (choose {span}{divided}): {targets or 'no legal target'}")
        if not announcement.get("slots"):
            lines.append("  no targets to choose")
    choice = view.get("choice") or {}
    if choice:
        source = f" ({choice['source']})" if choice.get("source") else ""
        lines.append(f"CHOICE{source}: {choice.get('prompt', '')} — pick {choice.get('count', 1)}"
                     + (" (cancel allowed)" if choice.get("cancel") else ""))
        for i, label in enumerate(choice.get("options", []) or []):
            lines.append(f"  {i}: {label}")
        for info in choice.get("information", []) or []:
            if isinstance(info, dict):
                lines.append(f"  shown — {info.get('title', '')}: {', '.join(str(c) for c in info.get('cards', []) or [])}")
    request = view.get("damage_request") or {}
    if request:
        targets = " | ".join(f"{t.get('id')} {t.get('name', '')} (lethal {t.get('lethal', 0)})"
                             for t in request.get("targets", []) or [] if isinstance(t, dict))
        lines.append(f"ASSIGN {request.get('amount', 0)} damage from {request.get('source', '?')}: {targets}")
    if view.get("discard_count") and view.get("mode") == "discard":
        lines.append(f"DISCARD {view['discard_count']} card(s) from your hand")
    information = [i for i in view.get("information", []) or [] if isinstance(i, dict)]
    if information:
        lines.append(f"SHOWN TO YOU (last {min(3, len(information))} of {len(information)}):")
        for info in information[-3:]:
            lines.append(f"  {info.get('title', '')}: {', '.join(str(c) for c in info.get('cards', []) or [])}")
    return lines


def _option_lines(mode: str, options: dict, view: dict, cards: dict, rows: dict) -> list[str]:
    """The decision's legal answers, one line each, with the op to send
    (or the one-call tool that sends it)."""
    lines = ["OPTIONS:"]
    if options.get("waiting"):
        return lines + ["  waiting — it is not your decision"]
    if mode == "opening":
        if options.get("order"):
            lines.append('  choose the order: {"op":"order","play":true} plays first, false draws first')
        lines.append('  keep: {"op":"keep"}')
        if options.get("mulligan"):
            lines.append(f'  mulligan ({options["mulligan"].get("hand", "?")} cards): {{"op":"mulligan"}}')
    elif mode == "attack":
        rows_ = (options.get("attack") or {}).get("attackable", []) or []
        names = ", ".join(f"{r.get('name')} {r.get('card')}" for r in rows_ if isinstance(r, dict))
        lines.append(f"  attack with any of: {names or 'nothing can attack'}")
        lines.append('  {"op":"attack","cards":[ids...]} — [] attacks with nothing')
    elif mode == "block":
        for row in (options.get("block") or {}).get("blockable", []) or []:
            if isinstance(row, dict):
                can = ", ".join(f"{a.get('name')} {a.get('card')}" for a in row.get("attackers", []) or [])
                lines.append(f"  {row.get('name')} {row.get('blocker')} can block: {can}")
        lines.append('  {"op":"block","pairs":[[blocker, attacker], ...]} — [] blocks nothing')
    elif mode == "discard":
        want = options.get("discard") or {}
        hand = ", ".join(f"{r.get('name')} {r.get('card')}" for r in want.get("hand", []) or [] if isinstance(r, dict))
        lines.append(f"  discard {want.get('count', 0)} of: {hand}")
        lines.append('  {"op":"discard","cards":[ids...]}')
    elif mode == "damage":
        lines.append('  {"op":"damage","points":[[id or "player", amount], ...]}')
    elif mode == "choice":
        lines.append('  {"op":"choice","picks":[index, ...]}' + (' | cancel: {"op":"cancel"}' if options.get("cancel") else ""))
    elif mode == "priority" and options.get("announcement"):
        lines.append('  pay: {"op":"autopay","excluded":[],"count":1}, then {"op":"submit","targets":[[token, amount], ...]}')
        lines.append('  withdraw: {"op":"cancel"} (mana already made stays in your pool)')
    elif mode == "priority":
        lines.append('  pass: {"op":"pass"} (or referee_act with `until`)')
        lands = (options.get("play") or {}).get("lands", []) or []
        if lands:
            lines.append("  play a land: " + ", ".join(f"{r.get('name')} {r.get('card')}" for r in lands if isinstance(r, dict))
                         + " (referee_play_land)")
        prepare = options.get("prepare") or {}
        casts = []
        for row in prepare.get("casts", []) or []:
            if not isinstance(row, dict):
                continue
            text = f"{row.get('name')} {row.get('card')}"
            cost = _spell_cost(rows.get(row.get("card")))
            if cost:
                text += f" {cost}"
            if row.get("x"):
                text += f" (X up to {row.get('budget', 0)})"
            if row.get("modes"):
                usable = row.get("usable_modes")
                usable = set(usable) if isinstance(usable, list) else set(range(len(row["modes"])))
                text += " modes: " + " / ".join(f"{i}={m}" + ("" if i in usable else " (not now)")
                                                for i, m in enumerate(row["modes"]))
            casts.append(text)
        if casts:
            lines.append("  cast: " + " | ".join(casts) + " (referee_cast)")
        abilities = []
        for row in prepare.get("abilities", []) or []:
            if isinstance(row, dict) and ability_usable(row):
                text = f"{row.get('name')} {row.get('card')} #{row.get('index', 0)}"
                label = str(row.get("label") or "")
                if row.get("cost") and not label.startswith(str(row["cost"])):
                    text += f" {row['cost']}"   # (a label that opens with its cost says it once)
                if label:
                    text += f" — {label}"
                abilities.append(text)
        if abilities:
            lines.append("  activate: " + " | ".join(abilities) + " (referee_cast kind=ability)")
        specials = (options.get("special") or {}).get("specials", []) or []
        for row in specials:
            if isinstance(row, dict):
                lines.append(f"  special {row.get('index')}: {row.get('label')}")
        sources = (options.get("mana") or {}).get("sources", []) or []
        if sources:
            lines.append(f"  mana abilities: {len(sources)} (autopay taps them for you)")
    lines.append('  concede: {"op":"concede"}')
    return lines


TEXTS = ("compact", "json")


def result_line(result: dict, me: int | None = None) -> str:
    """The end of a game in one line: who won (you or the opponent when
    the seat is known), the life totals, the turns and the reason."""
    winner = result.get("winner")
    if winner in (None, -1) or result.get("draw") and winner in (None, -1):
        who = "no winner (a draw)"
    elif me is not None and winner in (0, 1):
        who = f"{'YOU WON' if winner == me else 'you lost — the opponent won'} (seat {winner})"
    else:
        who = f"winner seat {winner}"
    life = result.get("life")
    if isinstance(life, list) and len(life) == 2 and me in (0, 1):
        life_text = f"life you {life[me]} / opponent {life[1 - me]}"
    else:
        life_text = f"life {life}" if life is not None else ""
    parts = [f"RESULT: {who}", life_text, f"turns {result.get('turns')}", f"reason {result.get('reason')}"]
    return " | ".join(p for p in parts if p)


def json_note(view: str | None, menu: bool = False) -> str:
    """The compact text's last line: where the JSON is."""
    if menu:
        return ("(The full JSON — `obs` with its `features` vector, `menu` with every item's id — is in "
                "structuredContent; `rich: true` adds each item's kind, info and ops.)")
    return (f"(The full JSON is in structuredContent — the decision in view `{view or 'brief'}`; views: "
            "brief, delta, full, options, compact. `text: \"json\"` on referee_start puts the JSON here instead.)")


def menu_text(state: dict, decision: dict | None, journal: list | None, me: int | None = None) -> str:
    """A menu tool's answer as the compact view's text: the header (the
    pick, the pass, the refusals), the board as `compact_view` draws it —
    the journal the menu's Driver kept, the wire's OPTIONS replaced by the
    MENU, numbered as `referee_pick` takes it — and the result."""
    lines = [f"game {state.get('game', '?')} | model decisions {state.get('n', 0)}"]
    if state.get("picked"):
        lines.append(f"picked: {state['picked'].get('label')} [{state['picked'].get('id')}]")
    if state.get("stop"):
        lines.append(f"stopped: {state['stop']} (passed {state.get('passed', 0)}, until {state.get('until')})")
    for refused in state.get("refused", []) or []:
        if isinstance(refused, dict):
            lines.append(f"REFUSED (decision {refused.get('n')}): {refused.get('reason')} — the item left the menu")
    if decision is not None and not state.get("result"):
        shown = dict(decision)
        shown["view"] = dict(decision.get("view") or {}, journal=list(journal or []))
        board = compact_view(shown).splitlines()
        if "OPTIONS:" in board:
            start = board.index("OPTIONS:")
            end = next((i for i in range(start + 1, len(board)) if board[i].startswith("JOURNAL (")), len(board))
            board = board[:start] + board[end:]
        lines.extend(board)
        obs = state.get("obs") or {}
        if obs.get("selection"):
            lines.append("SELECTING: " + json.dumps(obs["selection"], ensure_ascii=False, sort_keys=True))
        lines.append("MENU (answer with referee_pick {pick: N}):")
        for i, item in enumerate(state.get("menu") or []):
            lines.append(f"  {i}. {item.get('label')}  [{item.get('id')}]")
    result = state.get("result")
    if isinstance(result, dict):
        lines.append(result_line(result, me))
    if isinstance(state.get("error"), dict):
        lines.append(f"ERROR ({state['error'].get('kind')}): {state['error'].get('message')}")
    lines.append(json_note(None, menu=True))
    return "\n".join(lines)


def compact_answer(state: dict, decision_text: str | None = None, me: int | None = None) -> str:
    """A referee answer as the text an MCP client shows its model (the
    `compact` view): the game's header — what was sent, why the pass
    stopped, what was refused, what a one-call cast did — then the
    decision's compact board, or the result. `structuredContent` keeps
    the JSON."""
    lines = [f"game {state.get('game', '?')} | decisions {state.get('decisions', 0)} | "
             f"refusals {state.get('refusals', 0)}"]
    if state.get("action"):
        lines.append("sent: " + json.dumps(state["action"], ensure_ascii=False, sort_keys=True))
    cast = state.get("cast")
    if isinstance(cast, dict):
        lines.append("cast: " + cast_summary(cast))
        if state.get("sent"):
            lines.append("steps: " + " -> ".join(str(s.get("op")) for s in state["sent"] if isinstance(s, dict)))
    if state.get("stop"):
        lines.append(f"stopped: {state['stop']} (passed {state.get('passed', 0)}, until {state.get('until')})")
    elif "passed" in state and "until" in state:
        lines.append(f"passed {state.get('passed', 0)} (until {state.get('until')})")
    if "played" in state:
        lines.append(f"the pilot played {state['played']} decision(s)")
    for refused in state.get("refused", []) or []:
        if isinstance(refused, dict):
            lines.append(f"REFUSED (decision {refused.get('n')}): {refused.get('reason')}")
    if state.get("table") and state.get("pending"):
        table = state["table"]
        lines.append(f"table '{table.get('name')}' ({table.get('access')}) at {table.get('address')}:{table.get('port')} — "
                     f"invitation {table.get('invitation')}")
    if state.get("note"):
        lines.append(f"note: {state['note']}")
    if state.get("pending"):
        lines.append("PENDING: nothing arrived yet — referee_wait reads on")
    decision = state.get("decision")
    if isinstance(decision, dict):
        if decision.get("compact"):
            lines.append(decision["compact"])
        elif decision_text:
            lines.append(decision_text)
        else:
            lines.append(compact_view(decision) if "view" in decision else
                         json.dumps(decision, ensure_ascii=False, default=str))
    result = state.get("result")
    if isinstance(result, dict):
        lines.append(result_line(result, me))
    if isinstance(state.get("error"), dict):
        lines.append(f"ERROR ({state['error'].get('kind')}): {state['error'].get('message')}")
    return "\n".join(lines)


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


def no_choice_answer(decision: dict | None) -> dict | None:
    """The answer to a decision that offers no choice at all — an attack
    with nothing able to attack (`[]`), a block with nothing able to block
    (`[]`) — or None when the seat has something to decide."""
    if not isinstance(decision, dict):
        return None
    options = decision.get("options") or {}
    seat = decision.get("seat")
    mode = decision.get("mode")
    # Only a list the referee SENT and left empty means "nothing can": an
    # options shape without the list (an older referee) is never guessed at.
    attack = options.get("attack") or {}
    if mode == "attack" and "attackable" in attack and not attack["attackable"]:
        return {"op": "attack", "cards": [], "seat": seat}
    block = options.get("block") or {}
    if mode == "block" and "blockable" in block and not block["blockable"]:
        return {"op": "block", "pairs": [], "seat": seat}
    return None


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
    if until in ("mine", "mine-strict"):
        return mine_stop(options, view, seat, step, theirs, stack, strict=until == "mine-strict")
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


def ability_usable(row) -> bool:
    """A `prepare` row the seat can use now. The referee's lists are
    usable-only since 0.50.13 (a listed spell is castable, a listed
    ability legal and payable now); a row that says otherwise — `usable`,
    `castable`, `legal` or `activatable` false, or a `refusal` — is not
    counted either, for a referee that marks rather than drops."""
    if not isinstance(row, dict):
        return False
    if any(key in row and row[key] is False for key in ("usable", "castable", "legal", "activatable")):
        return False
    return not row.get("refusal")


def usable_now(options: dict) -> list[str]:
    """What the seat could use at this very moment, read from the
    decision's options (never from card types): every listed ability
    (non-mana — mana abilities live in `options.mana` and never count)
    and, while the referee says the seat can `respond` (some fast spell
    of its has something to aim at), every listed cast — at the
    opponent's turn that is an instant, a flash spell, a flash-rider
    Aura. A sorcery is never listed there; an exhausted once-per-turn
    ability is not listed at all."""
    prepare = options.get("prepare") or {}
    held = []
    if options.get("respond"):
        for row in prepare.get("casts", []) or []:
            if ability_usable(row):
                held.append(f"{row.get('name', '?')} (castable)")
    for row in prepare.get("abilities", []) or []:
        if ability_usable(row):
            held.append(f"{row.get('name', '?')}'s ability" + (f" {row['cost']}" if row.get("cost") else ""))
    return held


def mine_stop(options: dict, view: dict, seat: int, step: str, theirs: bool, stack: list,
              strict: bool) -> str:
    """`until: "mine"` (and `"mine-strict"`), a priority decision: the
    seat's own main phase with something to do stops; on the opponent's
    account (their spell or ability on top of the stack, their declared
    attackers, their blocks, their first-strike damage, their end step —
    and the blocks of the seat's own attack) only while `usable_now`
    names something, and the stop says what. `strict` passes those
    windows whatever the seat holds. The non-priority decisions (attack,
    block, discard, damage, choice) stopped before this is asked."""
    prepare = options.get("prepare") or {}
    work = ((options.get("play") or {}).get("lands")
            or any(ability_usable(r) for r in prepare.get("casts", []) or [])
            or any(ability_usable(r) for r in prepare.get("abilities", []) or [])
            or (options.get("special") or {}).get("specials"))
    if not theirs and step in OWN_MAIN and not stack and work:
        return "your main phase, with something to play"
    if strict:
        return ""
    held = usable_now(options)
    if not held:
        return ""
    hold = "you hold " + ", ".join(held)
    top = stack[-1] if stack and isinstance(stack[-1], dict) else None
    if top is not None and top.get("controller") != seat:
        return f"their {top.get('name', 'spell')} is on the stack; {hold}"
    if top is not None:
        # The seat's own spell or trigger on top (a flanking trigger in its
        # own blockers step): let it resolve — the window comes again with
        # the stack empty, and the stop is made there, once.
        return ""
    if theirs and step in REACT_STEPS_THEIRS and (step != "DECLARE_ATTACKERS" or attackers_declared(view)):
        return f"their {_words(step)}; {hold}"
    if not theirs and step in REACT_STEPS_OWN and attackers_declared(view):
        return f"your {_words(step)}; {hold}"
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


# --- one-call actions: cards by name, targets by what they are -------------

HANDLE = re.compile(r"^c\d+$")
TOKEN = re.compile(r"^t\d+$")
ME_WORDS = ("me", "you", "self", "myself", "mine", "my")
THEM_WORDS = ("opponent", "the opponent", "them", "opp", "enemy", "foe")
# The keys an op takes, filled in when a client leaves them out — the
# wire's own defaults, as the pilot sends them (friction 3 of the
# 2026-10-04 play-through: `autoprepare` was refused for want of `mode`,
# `excluded` and `count`).
ACTION_DEFAULTS = {
    "prepare": {"kind": "spell", "index": 0, "x": 0, "mode": 0},
    "autoprepare": {"kind": "spell", "index": 0, "mode": 0, "excluded": [], "count": 1},
    "autopay": {"excluded": [], "count": 1},
    "submit": {"targets": []},
    "attack": {"cards": []},
    "block": {"pairs": []},
}


class CastRefused(Exception):
    """A one-call action that cannot go on, with what was legal."""

    def __init__(self, message: str, kind: str = "cast", **more):
        super().__init__(message)
        self.message = message
        self.kind = kind
        self.more = more


def complete_action(action: dict, decision: dict | None) -> dict:
    """A client's action with the wire's defaults filled in for the keys
    it left out, and a `card` given by NAME (`"Plains"`) turned into the
    handle the decision's options list it under — the land to play, the
    spell or ability to prepare. A name the options do not list is left
    as typed: the referee's refusal is the answer."""
    out = dict(action)
    for key, value in ACTION_DEFAULTS.get(str(out.get("op")), {}).items():
        out.setdefault(key, json.loads(json.dumps(value)))
    card = out.get("card")
    if decision and isinstance(card, str) and card.strip() and not HANDLE.match(card.strip()):
        options = decision.get("options") or {}
        word = card.strip().casefold()
        if out.get("op") == "play":
            rows = (options.get("play") or {}).get("lands", []) or []
        elif out.get("op") in ("prepare", "autoprepare"):
            prepare = options.get("prepare") or {}
            rows = prepare.get("abilities" if out.get("kind") == "ability" else "casts", []) or []
        else:
            rows = []
        for row in rows:
            if isinstance(row, dict) and str(row.get("name", "")).casefold() == word:
                out["card"] = row.get("card")
                break
    return out


def player_of(word, seat: int) -> int | None:
    """A player named the way a client names one: `me`, `opponent`, a
    seat number, `player:1`, `seat 0` — or None."""
    if isinstance(word, bool):
        return None
    if isinstance(word, int):
        return word if word in (0, 1) else None
    text = str(word).strip().casefold()
    if text in ME_WORDS:
        return seat
    if text in THEM_WORDS:
        return 1 - seat
    found = re.fullmatch(r"(?:player|seat)?\s*[:_-]?\s*([01])", text)
    return int(found.group(1)) if found else None


def target_spec(spec) -> tuple:
    """(word, amount, slot) of one requested target: a word (`c9`,
    `Grizzly Bears`, `opponent`, `t2`), a `[word, amount]` pair, or
    `{target, amount, slot}`."""
    if isinstance(spec, dict):
        word = next((spec[k] for k in ("target", "card", "id", "player") if k in spec), None)
        return word, spec.get("amount"), spec.get("slot")
    if isinstance(spec, (list, tuple)) and len(spec) == 2:
        return spec[0], spec[1], None
    return spec, None, None


def slot_candidates(slot: dict, refs: dict) -> list[dict]:
    """A slot's targets as {token, label, what}: `what` is the handle
    (`c9`), `player:N`, `ability:aN`... — the referee's own `card` beside
    the token when it sends one, else the view's `presentation.targets`."""
    out = []
    for row in slot.get("targets", []) or []:
        if isinstance(row, dict):
            token = str(row.get("id", ""))
            out.append({"token": token, "label": str(row.get("label", "")),
                        "what": row.get("card") or refs.get(token)})
    return out


def legal_targets(announcement: dict, refs: dict) -> list[dict]:
    return [{"slot": i, "label": slot.get("label", ""), "min": slot.get("min", 0), "max": slot.get("max", 0),
             "divided": slot.get("divided", 0),
             "targets": [{"token": c["token"], "label": c["label"], **({"card": c["what"]} if c["what"] else {})}
                         for c in slot_candidates(slot, refs)]}
            for i, slot in enumerate(announcement.get("slots", []) or [])]


def _expected_label(card: dict, seat: int) -> str:
    """What SgDuelActions.target_label calls a card on the table — the
    fallback for a referee whose tokens carry no handle."""
    name = "Face-down creature" if card.get("masked") else card.get("name", "")
    owner = "yours" if card.get("controller") == seat else "opponent's"
    return f"{name} — {owner}" + (" (tapped)" if card.get("tapped") else "")


def resolve_target(word, slot: dict, refs: dict, cards: dict, seat: int) -> str | None:
    """The token of `slot` that `word` names, None when it names none of
    them; CastRefused when it names several."""
    rows = slot_candidates(slot, refs)
    text = str(word).strip() if not isinstance(word, (int, bool)) else str(word)
    if TOKEN.match(text):
        return text if any(r["token"] == text for r in rows) else None
    player = player_of(word, seat)
    matches: list[dict]
    if player is not None and not HANDLE.match(text):
        label = "You" if player == seat else "Opponent"
        matches = [r for r in rows if r["what"] == f"player:{player}" or (not r["what"] and r["label"] == label)]
    elif HANDLE.match(text):
        matches = [r for r in rows if r["what"] == text]
        if not matches and text in cards:
            # A referee that sends no handle beside its tokens: the label
            # the engine gives that card, when exactly one token wears it.
            label = _expected_label(cards[text], seat)
            same = [r for r in rows if not r["what"] and r["label"] == label]
            if len(same) > 1:
                raise CastRefused(f"several targets read '{label}' and this referee does not say which is {text}: "
                                  f"name its token ({', '.join(r['token'] for r in same)})", "target")
            matches = same
    else:
        name = text.casefold()
        matches = [r for r in rows
                   if (r["what"] in cards and str(cards[r["what"]].get("name", "")).casefold() == name)
                   or r["label"].casefold() == name or r["label"].casefold().startswith(name + " — ")
                   or r["label"].casefold() == "ability: " + name
                   # a trigger as a "spell or ability" target (protocol 28)
                   or r["label"].casefold() == "triggered ability: " + name]
        if len(matches) > 1:
            raise CastRefused(f"several targets are called '{text}': "
                              + "; ".join(f"{r['token']} {r['label']}" + (f" [{r['what']}]" if r["what"] else "")
                                          for r in matches) + " — name one by its id or token", "target")
    return matches[0]["token"] if matches else None


def slot_span(slot: dict, earlier_tokens) -> tuple[int, int]:
    """A slot's (min, max): its own — or, for a count an EARLIER target
    sets (protocol 28, Reap: "up to X target cards, where X is the number of
    black permanents target opponent controls"), the `counts` row of the
    earlier slot's token that was picked. The slot's own pair is then the
    widest any pick allows, which the referee refuses past."""
    low, high = int(slot.get("min", 0) or 0), int(slot.get("max", 0) or 0)
    for row in slot.get("counts") or []:
        if isinstance(row, list) and len(row) == 3 and str(row[0]) in earlier_tokens:
            return int(row[1]), int(row[2])
    return low, high


def map_targets(announcement: dict, view: dict, seat: int, wanted: list) -> list[dict]:
    """The requested targets laid onto the announcement's slots, in order:
    each target goes to the first slot (from the current one on) that has
    room and where it is legal — or to the slot it names. Divided amounts
    are checked (one target takes the whole amount; several without
    amounts share it evenly). Returns [{slot, token, label, target,
    amount}]; CastRefused, with the legal targets, when a target is not
    legal, a slot is short, or an amount does not add up."""
    refs = target_refs(view)
    cards = view_cards(view)
    slots = [s for s in announcement.get("slots", []) or [] if isinstance(s, dict)]
    placed: list[list[dict]] = [[] for _ in slots]
    legal = legal_targets(announcement, refs)

    def find(word, slot: dict) -> str | None:
        try:
            return resolve_target(word, slot, refs, cards, seat)
        except CastRefused as exc:
            raise CastRefused(exc.message, exc.kind, legal=legal) from None

    current = 0
    for spec in wanted or []:
        word, amount, slot_index = target_spec(spec)
        if word is None or (isinstance(word, str) and not word.strip()):
            raise CastRefused(f"a target is a card id, a card name, a player or a token — not {spec!r}", "target",
                              legal=legal)
        if slot_index is not None:
            if not isinstance(slot_index, int) or isinstance(slot_index, bool) or not 0 <= slot_index < len(slots):
                raise CastRefused(f"no slot {slot_index!r}: the announcement has {len(slots)}", "target", legal=legal)
            token = find(word, slots[slot_index])
            if token is None:
                raise CastRefused(f"{word} is not a legal target for slot {slot_index} "
                                  f"({slots[slot_index].get('label', '')})", "target", legal=legal)
            placed[slot_index].append({"token": token, "amount": amount, "word": word})
            continue
        while True:
            if current >= len(slots):
                raise CastRefused(f"{word}: more targets than the spell takes" if slots else
                                  f"{announcement.get('name', 'this')} takes no targets", "target", legal=legal)
            slot = slots[current]
            low, high = slot_span(slot, {p["token"] for row in placed[:current] for p in row})
            if len(placed[current]) >= high:
                current += 1
                continue
            token = find(word, slot)
            if token is not None and not any(p["token"] == token for p in placed[current]):
                placed[current].append({"token": token, "amount": amount, "word": word})
                break
            if len(placed[current]) >= low and current + 1 < len(slots):
                current += 1
                continue
            raise CastRefused(f"{word} is not a legal target for {announcement.get('name', 'this')} "
                              f"(slot {current}: {slot.get('label', '')})", "target", legal=legal)
    out: list[dict] = []
    for i, slot in enumerate(slots):
        rows = placed[i]
        low, high = slot_span(slot, {p["token"] for row in placed[:i] for p in row})
        if len(rows) < low:
            raise CastRefused(f"slot {i} ({slot.get('label', 'target')}) needs at least {low} target(s) "
                              f"— give `targets`", "target", legal=legal)
        if slot.get("counts") and len(rows) > high:
            raise CastRefused(f"slot {i} ({slot.get('label', 'target')}) takes at most {high} target(s) "
                              f"with the targets before it", "target", legal=legal)
        divided = int(slot.get("divided", 0) or 0)
        amounts = [r["amount"] for r in rows]
        if divided and rows:
            if all(a is None for a in amounts):
                share, extra = divmod(divided, len(rows))
                amounts = [share + (1 if k < extra else 0) for k in range(len(rows))]
            if any(not isinstance(a, int) or isinstance(a, bool) or a < 1 for a in amounts) or sum(amounts) != divided:
                raise CastRefused(f"slot {i} divides {divided} among its targets, at least 1 each — "
                                  f"not {amounts}", "target", legal=legal)
        else:
            amounts = [0] * len(rows)
        labels = {c["token"]: c for c in slot_candidates(slot, refs)}
        for row, amount in zip(rows, amounts):
            found = labels.get(row["token"], {})
            out.append({"slot": i, "token": row["token"], "label": found.get("label", ""),
                        "target": found.get("what") or str(row["word"]), "amount": amount})
    return out


def cast_summary(cast: dict) -> str:
    """One line for a one-call cast's outcome (the compact view)."""
    text = f"{cast.get('name', '?')} {cast.get('card', '')} ({cast.get('kind', 'spell')}"
    if cast.get("x"):
        text += f", X={cast['x']}"
    if cast.get("mode"):
        text += f", mode {cast['mode']}"
    text += ")"
    if cast.get("targets"):
        text += " -> " + "; ".join(f"{t.get('label') or t.get('target')}" + (f" ({t['amount']})" if t.get("amount") else "")
                                    for t in cast["targets"])
    text += f": {cast.get('result', '?')}"
    if cast.get("reason"):
        text += f" — {cast['reason']}"
    if cast.get("floating_mana"):
        text += f" | floating mana {cast['floating_mana']}"
    if cast.get("note"):
        text += f" | {cast['note']}"
    return text


def floating_mana(decision: dict | None) -> str:
    """The seat's mana pool as `W1 C2`, '' when empty."""
    view = (decision or {}).get("view") or {}
    seat = (decision or {}).get("seat")
    for player in view.get("players", []) or []:
        if isinstance(player, dict) and player.get("seat") == seat and player.get("mana"):
            pool = player.get("mana_colors") or []
            return " ".join(f"{c}{n}" for c, n in zip("WUBRGC", pool) if n) or str(player["mana"])
    return ""


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
        # THE JOURNAL IS NEVER LOST (2026-10-04): `fresh` says the pending
        # decision's journal lines have reached nobody yet — neither shown
        # nor kept in `passed_journal`. An action sent on a fresh decision
        # (a pass of `until`, the pilot's answer, a step of a one-call
        # cast) keeps its lines first, so the next decision shown carries
        # them; before, `referee_autoplay` dropped every journal line but
        # the last decision's. `delta_base` is the brief the shown delta
        # was taken against (`referee_view` renders it again).
        self.fresh = False
        self.delta_base: dict | None = None
        self.shown_record: dict | None = None
        # What a referee answer's `content` holds (0.50.13): the compact
        # text (default) or the JSON (`text: "json"`).
        self.text = "compact"
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

    def absorb(self) -> None:
        """Keep a fresh pending decision's journal for the next decision
        shown — it is about to be answered without being shown."""
        if self.fresh and self.pending is not None:
            self.passed_journal += list((self.pending.get("view") or {}).get("journal") or [])
        self.fresh = False

    def send(self, action: dict) -> None:
        if not self.running:
            raise refusal("referee", "game", f"game {self.ident} is over", game=self.ident)
        self.absorb()
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
                self.fresh = True
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
        self.fresh = False
        brief = brief_view(self.pending.get("view", {}), int(self.pending.get("seat", 0)))
        if self.pending is not self.shown_record:
            # (the same decision shown again keeps the delta it was shown with)
            self.delta_base = self.last_brief
            self.shown_record = self.pending
        out = render_decision(self.pending, self.view, self.delta_base, brief)
        self.last_brief = brief
        return out

    def render(self, mode: str) -> dict:
        """The pending decision in another view, for `referee_view`: a
        read, so neither the game's own view nor the delta's base moves."""
        assert self.pending is not None
        brief = brief_view(self.pending.get("view", {}), int(self.pending.get("seat", 0)))
        base = self.delta_base if self.pending is self.shown_record else self.last_brief
        return render_decision(self.pending, mode, base, brief)

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
                    "whole brief, marked `baseline`); `compact` the board, the hand, the stack, "
                    "the open prompt with its tokens, the legal answers and the journal as a few "
                    "lines of text — the answer's `content` (what a model reads), the brief's JSON "
                    "staying in `structuredContent`; `full` the referee's whole LAN view; "
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
        text = prop("string", "what each referee answer's `content` holds, remembered for the game: "
                    "`compact` (default) the table summary as text — the board, your hand, the stack, the "
                    "prompt, the legal answers, the journal, or the end of the game — `json` the JSON "
                    "itself; `structuredContent` is the JSON either way", enum=list(TEXTS))
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
                       "unknown name answers `known: false` with `near` — the nearest real names. "
                       "Every pack the server finds is searched unless `packs` says otherwise.",
                       {"names": prop("array", "one or more exact card names", items={"type": "string"},
                                      minItems=1),
                        "packs": prop("string", "the card packs to look in: `all`, `none`, or ids `1,8` "
                                      "(unset: every pack the server finds — `all`)")},
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
                        "rules": prop("string", "the table's rules preset, passed to the referee: `modern`, "
                                      "`modern_mana_burn` (the referee's default) or `fifth`; reported as "
                                      "`hello.rules`"),
                        "log": prop("string", "write the engine's own log of the duel here at the end"),
                        "keep": keep, "view": view, "text": text, "timeout": timeout},
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
                        "packs": packs, "keep": keep, "view": view, "text": text,
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
                        "packs": packs, "keep": keep, "view": view, "text": text,
                        "rules": prop("string", "the table's rules preset: `modern`, `modern_mana_burn` "
                                      "(default) or `fifth` (a joined table plays its host's)"),
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
                       "discard, damage and choice of your own. RECOMMENDED: `mine` — the smart "
                       "pass: your own main phase with something to do and every decision of your "
                       "own (attack, block, discard, damage, choice), and the opponent's spell on "
                       "the stack or their combat and end steps ONLY while you hold something "
                       "usable right then (a castable instant or flash spell, a legal non-mana "
                       "ability) — the stop says what you hold; `mine-strict` never stops for the "
                       "opponent's turn at all. The answer says `stop` (why it stopped), `passed` "
                       "(decisions passed), and the journal of everything passed over is in the "
                       "decision shown. Missing keys of an op are filled with the wire's defaults "
                       "(`prepare` kind spell, index 0, x 0, mode 0; `autopay` excluded [], count 1; "
                       "...), a `card` may be named by name, and `{\"op\":\"cast\"}` / "
                       "`{\"op\":\"activate\"}` take `referee_cast`'s keys.",
                       {"game": game,
                        "action": {"description": "the answer: an object with `op` (the seat is "
                                   "filled in), or `default`", "type": ["object", "string"]},
                        "until": prop("string", "pass priority after this answer up to: `mine` (recommended: "
                                      "your next real decision), `mine-strict`, `main`, `end`, `turn`, "
                                      "`play`, `respond` (unset: the next decision)", enum=list(UNTIL)),
                        "view": view, "timeout": timeout},
                       self.tool_referee_act, required=["game", "action"]),
            self._tool("referee_cast", "Cast a spell or activate an ability in ONE call: prepare, "
                       "pay (the auto-tap) and submit, the targets named by what they are — a card's "
                       "id (`c9`) or name, `me`, `opponent` or a seat, an announcement token (`t2`), "
                       "with amounts for a divided spell (`[\"c9\", 2]` or `{target, amount, slot}`). "
                       "A target that is not legal is refused with the legal ones BEFORE any mana is "
                       "made; a payment or a submission the referee refuses is withdrawn (`cancel`) "
                       "and comes back as the refusal with the mana left floating — never a "
                       "half-announced cast. A question the payment asks (which colour) comes back "
                       "`open`: answer it with `referee_act`, then `referee_cast` the same card again. "
                       "`until` then passes priority as `referee_act`'s does.",
                       {"game": game,
                        "card": prop("string", "the spell or the permanent: its id (`c7`) or its name"),
                        "kind": prop("string", "`spell` (default) or `ability`", enum=["spell", "ability"]),
                        "index": prop("integer", "which ability of the card (the `#` in the options); "
                                      "needed only when it has several usable now", minimum=0),
                        "x": prop("integer", "X, for a spell or ability with X (required there)", minimum=0),
                        "mode": {"description": "a modal spell's mode: its index or its label (required "
                                 "for a modal spell)", "type": ["integer", "string"]},
                        "targets": {"description": "the targets in slot order: card ids or names, `me`, "
                                    "`opponent`, 0/1, tokens, `[target, amount]` pairs or `{target, amount, "
                                    "slot}` objects", "type": "array"},
                        "exclude": prop("array", "permanents the auto-tap must not tap (ids)",
                                        items={"type": "string"}),
                        "until": prop("string", "after the cast, pass priority up to (as referee_act's "
                                      "`until`; `mine` recommended)", enum=list(UNTIL)),
                        "view": view, "timeout": timeout},
                       self.tool_referee_cast, required=["game", "card"]),
            self._tool("referee_play_land", "Play a land in one call, by its id or its name (unset: "
                       "the first land the options offer); refused with the playable lands when it "
                       "cannot be played now. `until` then passes priority as `referee_act`'s does.",
                       {"game": game,
                        "card": prop("string", "the land: its id (`c3`) or its name (unset: the first playable)"),
                        "until": prop("string", "after the land, pass priority up to (as referee_act's "
                                      "`until`)", enum=list(UNTIL)),
                        "view": view, "timeout": timeout},
                       self.tool_referee_play_land, required=["game"]),
            self._tool("referee_view", "Read the pending decision again in any view — `compact`, "
                       "`brief`, `delta`, `full`, `options` — without acting, and without changing "
                       "the view the game answers in (`referee_wait` with `view` changes it).",
                       {"game": game, "view": view},
                       self.tool_referee_view, required=["game"]),
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
                        "view": view, "text": text,
                        "timeout": prop("number", "seconds to wait for the referee's answer (default 30)")},
                       self.tool_referee_resume),
            *self._decision_tools(game, view, timeout),
        ]

    def _decision_tools(self, game: dict, view: dict, timeout: dict) -> list[dict]:
        """THE DECISION-MODEL BRIDGE (0.50.13): `referee_menu` and
        `referee_pick`, built on `tools/decision_menu.py` (its Driver plays
        the server's own `Game`), after the referee's tools, sharing the
        `game`, `view` and `timeout` properties (AGENTS.md, "Decision
        models")."""
        rich = prop("boolean", "each menu item also carries its kind, info (card, name, mana value, "
                    "P/T, target) and the wire ops it expands to")
        return [
            self._tool("referee_menu",
                       "The pending decision of a game as a NUMBERED MENU for a decision model (a small "
                       "model, a bot, a learning policy): `obs` (a compact observation from your side, with "
                       "`features`, a fixed numeric vector) and `menu` — every complete legal action as "
                       "{id, label}: pass, play:c3, cast:c12->opp (one item per legal target), act:c5:0, "
                       "attack:add:c7, block:c4->c9, choice:1, ... Item 0 is always 'do nothing'. Answer "
                       "with `referee_pick`; a menu of one legal item is answered for you. Reads the "
                       "referee's own announcement of each aimed spell first (a prepare and a cancel, "
                       "nothing paid). In the `compact` view the answer's text is the board and the menu "
                       "as numbered lines.",
                       {"game": game, "rich": rich,
                        "probe": prop("boolean", "read each aimed spell's targets ahead so the menu lists "
                                      "`cast S -> T` flat (default true; false: a target sub-menu after the "
                                      "cast; applies when the game's menu is first made)"),
                        "view": view, "timeout": timeout},
                       self.tool_referee_menu, required=["game"]),
            self._tool("referee_pick",
                       "Apply one item of the game's `referee_menu` — its index, its id, or {\"pick\": ...} — "
                       "and answer with the next menu (or the `result`). The server sends the wire ops itself "
                       "(prepare, autopay once the payment is reachable, submit; the attack, block and choice "
                       "lists); a sub-menu step (attack:add, block pairs, discard and choice picks, target "
                       "picks) sends nothing until its last pick. A refused step is cancelled at once and the "
                       "item leaves the menu; `refused` lists it. With `until` the server then passes priority "
                       "as referee_act's `until` does (`mine` recommended).",
                       {"game": game,
                        "pick": {"description": "the menu item: its index (0..), its id, or {\"pick\": INDEX or ID}",
                                 "type": ["integer", "string", "object"]},
                        "until": prop("string", "after the pick, pass priority up to: " + ", ".join(UNTIL),
                                      enum=list(UNTIL)),
                        "rich": rich, "view": view, "timeout": timeout},
                       self.tool_referee_pick, required=["game", "pick"]),
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
        """A card's record. Without `packs` every pack the server can find
        is in play (`--packs all`, 2026-10-04): a card of a pack the game's
        own setting leaves off — Pack 8 in a fresh profile — used to come
        back `known: false`. Should that be refused (a found pack that
        cannot be enabled), the game's own setting answers instead."""
        names = self.strings(args["names"], "cards", "names")
        if args.get("packs"):
            return self.quote("cards", self.run("cards", ["--packs", str(args["packs"])] + names), require_json=True)
        try:
            return self.quote("cards", self.run("cards", ["--packs", "all"] + names), require_json=True)
        except ToolError as exc:
            if exc.envelope.get("kind") != "packs":
                raise
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

    def new_game(self, argv: list[str], view: str, keep: bool = False, text: str = "compact") -> Game:
        ident = self.claim_game()
        folder = self.workspace / "games"
        stderr = folder / f"{ident}.stderr"
        if not keep:
            game = Game(ident, self.command("referee", argv), view, self.root, stderr,
                        cancelled=self.is_cancelled)
            game.text = text
            self.games[ident] = game
            return game
        folder.mkdir(parents=True, exist_ok=True)
        record = {"game": ident, "argv": argv, "view": view, "text": text, "keep": str(folder / f"{ident}.keep.json"),
                  "lines": str(folder / f"{ident}.lines"), "stderr": str(stderr), "started": time.time()}
        for stale in (Path(record["keep"]), Path(record["lines"])):
            try:
                stale.unlink()
            except OSError:
                pass
        full = self.command("referee", argv + ["--listen", record["keep"], "--idle", str(KEEP_IDLE)])
        record["command"] = full
        game = Game(ident, full, view, self.root, stderr, keep=record, cancelled=self.is_cancelled)
        game.text = text
        (folder / f"{ident}.json").write_text(json.dumps(record, indent=1), encoding="utf-8")
        self.games[ident] = game
        return game

    def open_game(self, argv: list[str], view: str, timeout: float, keep: bool = False,
                  until_table: bool = False, text: str = "compact") -> dict:
        game = self.new_game(argv, view, keep, text)
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
        text = self.text_of(args, str(record.get("text") or "compact"))
        game = Game(ident, list(record.get("command") or []), view, self.root,
                    Path(record.get("stderr") or self.workspace / "games" / f"{ident}.stderr"),
                    keep=record, resume=True, cancelled=self.is_cancelled)
        game.text = text
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
        return self.present(game, state)

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
        for key in ("seed", "turns", "packs", "rules"):
            self.flag(argv, args, key, "--" + key)
        if args.get("log"):
            argv += ["--log", str(self.inside(args["log"], tool, "log"))]
        return self.shown_state(self.open_game(argv, self.view_of(args),
                                               float(args.get("timeout") or DECISION_TIMEOUT),
                                               keep=bool(args.get("keep", False)), text=self.text_of(args)))

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
        return self.shown_state(self.open_game(argv, self.view_of(args), float(args.get("timeout") or 15),
                                               keep=bool(args.get("keep", True)), text=self.text_of(args)))

    def tool_referee_host(self, args: dict) -> dict:
        tool = "referee"
        argv = ["--host", str(args["table"]), "--deck", self.deck_arg(args["deck"])]
        for key in ("access", "name", "port", "address", "wait", "turns", "packs", "rules"):
            self.flag(argv, args, key, "--" + key)
        if args.get("log"):
            argv += ["--log", str(self.inside(args["log"], tool, "log"))]
        state = self.open_game(argv, self.view_of(args), float(args.get("timeout") or 15),
                               keep=bool(args.get("keep", True)), until_table=True, text=self.text_of(args))
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
        return self.shown_state(state)

    def shown_state(self, state: dict):
        """`present` for an answer that names its game by id."""
        return self.present(self.games.get(str(state.get("game"))), state)

    def game_of(self, args: dict) -> Game:
        ident = str(args["game"])
        game = self.games.get(ident)
        if game is None:
            raise refusal("referee", "game", f"no game {ident}", game=ident,
                          games=sorted(self.games))
        return game

    def present(self, game: Game | None, state: dict, view: str | None = None):
        """A referee answer as it goes out. One that carries a decision or
        a result is an `Answer` whose `content` is the COMPACT TEXT —
        whatever `view` the JSON is rendered in (0.50.13: what an MCP
        client shows its model, every turn, without asking) — unless the
        game was opened with `text: "json"`; the JSON is the
        `structuredContent` either way, exactly as `view` renders it."""
        if game is None or game.text == "json":
            return state
        if not isinstance(state.get("decision"), dict) and not isinstance(state.get("result"), dict):
            return state
        return Answer(state, self.answer_text(game, state, view or game.view))

    def answer_text(self, game: Game, state: dict, view: str) -> str:
        """The compact text of a referee answer: the decision drawn from
        the referee's own line (whatever view the JSON shows), the end of
        the game in a line, and where the JSON is."""
        decision = state.get("decision")
        drawn = None
        if isinstance(decision, dict) and not decision.get("compact") and "view" not in decision:
            raw = game.pending
            if raw is not None and raw.get("n") == decision.get("n") and raw.get("seat") == decision.get("seat"):
                drawn = compact_view(raw)
        note = json_note(view) if isinstance(decision, dict) else "(The full JSON, the result's, is in structuredContent.)"
        return compact_answer(state, drawn, self.my_seat(game)) + "\n" + note

    @staticmethod
    def my_seat(game: Game) -> int | None:
        """The seat this client plays, when it plays one: the table's seat,
        or the one `agent` seat of a local duel (None when it plays both)."""
        hello = game.hello or {}
        table = hello.get("table") if isinstance(hello.get("table"), dict) else {}
        if isinstance(table.get("seat"), int):
            return table["seat"]
        agents = [s.get("seat") for s in hello.get("seats") or [] if isinstance(s, dict) and s.get("player") == "agent"]
        return agents[0] if len(agents) == 1 and isinstance(agents[0], int) else None

    @staticmethod
    def text_of(args: dict, fallback: str = "compact") -> str:
        text = args.get("text") or fallback
        if text not in TEXTS:
            raise refusal("referee", "option", f"`text` is one of {', '.join(TEXTS)}", flag="text")
        return text

    @staticmethod
    def until_of(args: dict) -> str | None:
        until = args.get("until")
        if until is not None and until not in UNTIL:
            raise refusal("referee", "option", f"`until` is one of {', '.join(UNTIL)}", flag="until",
                          suggestions=difflib.get_close_matches(str(until), UNTIL, n=2))
        return until

    def tool_referee_act(self, args: dict) -> dict:
        game = self.game_of(args)
        if game.result is not None or game.error is not None:
            return self.present(game, game.summary())
        if game.pending is None:
            raise refusal("referee", "game", f"game {game.ident} has no decision pending — referee_wait reads on",
                          game=game.ident)
        if args.get("view"):
            game.view = self.view_of(args)
        # `until` is checked before anything is sent — or the pilot asked.
        until = self.until_of(args)
        timeout = float(args.get("timeout") or DECISION_TIMEOUT)
        action = args["action"]
        if action == "default":
            action = default_answer(game.pending, game.memory)
        if not isinstance(action, dict) or "op" not in action:
            raise refusal("referee", "option", "`action` is an object with `op`, or `default`", flag="action")
        if action.get("op") in ("cast", "activate"):
            # The one-call cast, spelled as an action (2026-10-04).
            spec = {k: v for k, v in action.items() if k not in ("op", "seat")}
            spec.setdefault("kind", "ability" if action["op"] == "activate" else "spell")
            return self.cast(game, spec, until, timeout)
        action = complete_action(action, game.pending)
        action.setdefault("seat", game.pending.get("seat"))
        origin = game.pending
        game.send(action)
        state = self.after_send(game, until, origin, timeout)
        state["action"] = action
        self.settle(game)
        return self.present(game, state)

    def after_send(self, game: Game, until: str | None, origin: dict, timeout: float) -> dict:
        """The answer has gone: the next decision, or with `until` the one
        the pass stops at."""
        if until is None:
            return game.advance(timeout)
        return self.pass_until(game, until, origin, timeout)

    def pass_until(self, game: Game, until: str, origin: dict, timeout: float, waiting: bool = True) -> dict:
        """After the client's own answer: pass priority for it until
        `stop_reason` names a place a player would act, the result, an
        error, a refusal, a timeout or MAX_PASSES. The journal of every
        decision passed over is kept for the one shown (`Game.send`
        keeps a fresh decision's lines before it answers it). `waiting`
        false: the pending decision has arrived already and is judged
        first (a one-call cast's next decision)."""
        passed = 0
        refused: list[dict] = []
        state: dict = {} if waiting else game._state([], render=False)
        while True:
            if waiting:
                state = game.advance(timeout, render=False)
                refused += state.get("refused", [])
                if state.get("pending") or game.pending is None or refused:
                    break
            waiting = True
            empty = no_choice_answer(game.pending) if until in ("mine", "mine-strict") else None
            if empty is not None and passed < MAX_PASSES:
                # An attack with nothing able to attack, a block with nothing
                # able to block: there is no choice to make, so the smooth
                # modes answer it ([]) and keep passing (owner, 2026-10-04).
                game.send(empty)
                passed += 1
                continue
            reason = stop_reason(game.pending, until, origin)
            if reason:
                state["stop"] = reason
                break
            if passed >= MAX_PASSES:
                state["stop"] = f"{MAX_PASSES} decisions passed and `{until}` was not reached"
                break
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

    # ----- the one-call actions (2026-10-04) --------------------------------

    def tool_referee_cast(self, args: dict) -> dict:
        game = self.game_of(args)
        if args.get("view"):
            game.view = self.view_of(args)
        until = self.until_of(args)
        timeout = float(args.get("timeout") or DECISION_TIMEOUT)
        spec = {k: v for k, v in args.items() if k not in ("game", "view", "until", "timeout")}
        return self.cast(game, spec, until, timeout)

    def open_decision(self, game: Game, tool: str) -> dict:
        if game.result is not None or game.error is not None:
            raise refusal(tool, "game", f"game {game.ident} is over", game=game.ident,
                          result=game.result, error=game.error)
        if game.pending is None:
            raise refusal(tool, "game", f"game {game.ident} has no decision pending — referee_wait reads on",
                          game=game.ident)
        return game.pending

    def cast(self, game: Game, spec: dict, until: str | None, timeout: float) -> dict:
        """Prepare, pay and submit one spell or ability in one call, its
        targets named by what they are. Nothing is left half-announced:
        a target that is not legal is refused before any mana is made
        (the announcement withdrawn), and a payment or a submission the
        referee refuses is withdrawn too — the refusal comes back with
        the mana that was made and now floats. A question the payment
        itself asks (which colour a Fellwar Stone makes) is the seat's to
        answer: the cast comes back open, the question pending."""
        tool = "referee_cast"
        decision = self.open_decision(game, tool)
        kind = spec.get("kind") or "spell"
        if kind not in ("spell", "ability"):
            raise refusal(tool, "option", "`kind` is `spell` or `ability`", flag="kind")
        word = spec.get("card")
        if word is None or (isinstance(word, str) and not word.strip()):
            raise refusal(tool, "option", f"{tool} needs `card` — its id (c7) or its name", flag="card")
        word = str(word).strip()
        wanted = spec.get("targets") or []
        if not isinstance(wanted, list):
            wanted = [wanted]
        excluded = [str(x) for x in (spec.get("exclude") or [])]
        options = decision.get("options") or {}
        view = decision.get("view") or {}
        seat = int(decision.get("seat", 0))
        mode_name = str(decision.get("mode") or "")
        cards = view_cards(view)
        draft = options.get("draft") or {}
        steps: list[dict] = []
        refused: list[dict] = []
        cast: dict = {"kind": kind}
        if options.get("announcement"):
            open_card = str(draft.get("card") or "")
            if word != open_card and word.casefold() != str((cards.get(open_card) or {}).get("name", "")).casefold():
                raise refusal(tool, "cast", f"the announcement of {_named(cards.get(open_card), open_card)} is open — "
                              "finish it (referee_cast with that card resumes it) or withdraw it with "
                              "referee_act {\"op\":\"cancel\"}", game=game.ident)
            # A cast left open by its payment's question, taken up again:
            # the payment resumed when the question was answered.
            cast.update({"card": open_card, "name": (cards.get(open_card) or {}).get("name", ""),
                         "kind": draft.get("kind", kind), "index": draft.get("index", 0),
                         "x": draft.get("x", 0), "mode": draft.get("mode", 0), "resumed": True})
            return self.cast_submit(game, cast, wanted, until, decision, timeout, steps, refused, paid=True)
        if mode_name != "priority":
            raise refusal(tool, "cast", f"this decision is `{mode_name}`, not priority — answer it with referee_act",
                          game=game.ident)
        entry = self.cast_entry(options, cards, word, kind, spec.get("index"), tool)
        x = spec.get("x")
        if kind == "ability":
            pass   # (an ability row carries no `x` flag: a given X is the referee's to judge)
        elif entry.get("x"):
            if x is None:
                raise refusal(tool, "option", f"{entry.get('name')} has an X: give `x` (you can pay X up to "
                              f"{entry.get('budget', 0)})", flag="x", budget=entry.get("budget", 0))
        elif x not in (None, 0):
            raise refusal(tool, "option", f"{entry.get('name')} has no X", flag="x")
        if x is not None and (not isinstance(x, int) or isinstance(x, bool) or x < 0):
            raise refusal(tool, "option", "`x` is a whole number, 0 or more", flag="x")
        modes = entry.get("modes") or []
        mode = spec.get("mode")
        # The modes castable right now (the referee's `usable_modes`, 0.50.13
        # — a Fireblast whose Mountains are there, an alternative cost that
        # can be paid); every mode when an older referee does not say.
        usable = entry.get("usable_modes")
        usable = [m for m in usable if isinstance(m, int)] if isinstance(usable, list) else list(range(len(modes)))
        named = ", ".join(f"{i} ({modes[i]})" for i in usable if 0 <= i < len(modes)) or "none"
        if modes:
            if isinstance(mode, str):
                found = [i for i, label in enumerate(modes) if str(label).casefold() == mode.strip().casefold()]
                mode = found[0] if found else mode
            if mode is None:
                if not usable:
                    raise refusal(tool, "cast", f"{entry.get('name')}: no mode can be cast now", flag="mode",
                                  modes=modes, usable_modes=[])
                mode = usable[0]   # the first mode castable now
            if not isinstance(mode, int) or isinstance(mode, bool) or not 0 <= mode < len(modes):
                raise refusal(tool, "option", f"{entry.get('name')}: `mode` is one of "
                              + ", ".join(f"{i} ({label})" for i, label in enumerate(modes))
                              + f" — castable now: {named}", flag="mode", modes=modes, usable_modes=usable)
            if mode not in usable:
                raise refusal(tool, "cast", f"{entry.get('name')}: mode {mode} ({modes[mode]}) cannot be cast now "
                              f"— castable now: {named} (nothing was sent)", flag="mode", modes=modes,
                              usable_modes=usable)
        elif mode not in (None, 0):
            raise refusal(tool, "option", f"{entry.get('name')} has no modes", flag="mode")
        cast.update({"card": entry.get("card"), "name": entry.get("name"), "index": int(entry.get("index", 0) or 0),
                     "x": int(x or 0), "mode": int(mode or 0)})
        prepare = {"op": "prepare", "card": cast["card"], "kind": kind, "index": cast["index"],
                   "x": cast["x"], "mode": cast["mode"], "seat": seat}
        state = self.cast_step(game, prepare, timeout, steps, refused)
        if refused:
            # Refused before any announcement was made: nothing to withdraw.
            self.cast_refused(game, cast, "prepare", refused[-1].get("reason", "refused"), steps, refused)
        if state.get("pending") or game.pending is None:
            return self.cast_answer(game, state, cast, "open", steps, refused,
                                    note="the referee has not answered yet — referee_wait reads on")
        now = game.pending
        if not (now.get("options") or {}).get("announcement"):
            return self.cast_answer(game, state, cast, "open", steps, refused,
                                    note=f"no announcement followed the prepare (decision `{now.get('mode')}`)")
        if not ((now.get("options") or {}).get("draft") or {}).get("reachable", True):
            self.cast_withdraw(game, timeout, steps, refused)
            self.cast_refused(game, cast, "prepare", "the cost cannot be paid now (nothing was tapped)", steps, refused)
        announcement = (now.get("options") or {}).get("announcement") or {}
        try:
            # The targets are laid on the slots BEFORE anything is paid.
            planned = map_targets(announcement, now.get("view") or {}, seat, wanted)
        except CastRefused as exc:
            self.cast_withdraw(game, timeout, steps, refused)
            self.cast_refused(game, cast, "targets", exc.message + " (nothing was tapped)", steps, refused,
                              kind=exc.kind, **exc.more)
        count = max(1, len(planned))
        state = self.cast_step(game, {"op": "autopay", "excluded": excluded, "count": count, "seat": seat},
                               timeout, steps, refused)
        if refused and "no mana payment" not in str(refused[-1].get("reason", "")):
            reason = refused[-1].get("reason", "refused")
            self.cast_withdraw(game, timeout, steps, refused)
            self.cast_refused(game, cast, "autopay", reason, steps, refused)
        if refused:
            refused.pop()   # a cost of no mana: nothing to pay, nothing went wrong
        if state.get("pending") or game.pending is None:
            return self.cast_answer(game, state, cast, "open", steps, refused,
                                    note="the referee has not answered yet — referee_wait reads on")
        if game.pending.get("mode") == "choice":
            return self.cast_answer(game, state, cast, "open", steps, refused,
                                    note="the payment asks a question: answer it with referee_act "
                                    "{\"op\":\"choice\",\"picks\":[i]}, then referee_cast the same card again "
                                    "to submit (or referee_act {\"op\":\"cancel\"} to withdraw)")
        return self.cast_submit(game, cast, wanted, until, decision, timeout, steps, refused, paid=True)

    def cast_submit(self, game: Game, cast: dict, wanted: list, until: str | None, origin: dict,
                    timeout: float, steps: list, refused: list, paid: bool) -> dict:
        now = game.pending or {}
        seat = int(now.get("seat", 0))
        announcement = (now.get("options") or {}).get("announcement") or {}
        if not announcement:
            return self.cast_answer(game, game._state([], render=False), cast, "open", steps, refused,
                                    note=f"no announcement is open (decision `{now.get('mode')}`)")
        try:
            # Laid again on the slots as they are NOW: the payment may have
            # tapped a target, and a token is minted afresh each view.
            planned = map_targets(announcement, now.get("view") or {}, seat, wanted)
        except CastRefused as exc:
            self.cast_withdraw(game, timeout, steps, refused)
            self.cast_refused(game, cast, "targets", exc.message, steps, refused, kind=exc.kind, **exc.more)
        cast["targets"] = planned
        submit = {"op": "submit", "targets": [[p["token"], p["amount"]] for p in planned], "seat": seat}
        state = self.cast_step(game, submit, timeout, steps, refused)
        if refused and str(refused[-1].get("reason", "")).startswith("not enough mana") and paid \
                and game.pending is not None and (game.pending.get("options") or {}).get("announcement"):
            # The named targets priced it higher (a spell aimed at Kaervek's
            # Torch costs {2} more): the draft keeps them now, so one more
            # payment covers the surcharge, then the same submission.
            self.cast_step(game, {"op": "autopay", "excluded": [], "count": max(1, len(planned)), "seat": seat},
                           timeout, steps, refused)
            if game.pending is not None and (game.pending.get("options") or {}).get("announcement"):
                try:
                    retry = map_targets((game.pending.get("options") or {}).get("announcement") or {},
                                        game.pending.get("view") or {}, seat, wanted)
                except CastRefused as exc:
                    self.cast_withdraw(game, timeout, steps, refused)
                    self.cast_refused(game, cast, "targets", exc.message, steps, refused, kind=exc.kind, **exc.more)
                before = len(refused)
                state = self.cast_step(game, {"op": "submit", "targets": [[p["token"], p["amount"]] for p in retry],
                                              "seat": seat}, timeout, steps, refused)
                if len(refused) == before:
                    refused.clear()
        if refused:
            reason = refused[-1].get("reason", "refused")
            self.cast_withdraw(game, timeout, steps, refused)
            self.cast_refused(game, cast, "submit", reason, steps, refused)
        cast["result"] = "cast"
        if state.get("pending") or game.pending is None:
            return self.cast_answer(game, state, cast, "cast", steps, refused)
        if until is not None:
            state = self.pass_until(game, until, origin, timeout, waiting=False)
        return self.cast_answer(game, state, cast, "cast", steps, refused)

    def cast_entry(self, options: dict, cards: dict, word: str, kind: str, index, tool: str) -> dict:
        """The `prepare` row `word` names — by handle or by name; among
        several of one name the untapped card first; an ability by its
        `index` when the card has more than one usable now."""
        prepare = options.get("prepare") or {}
        rows = [r for r in prepare.get("casts" if kind == "spell" else "abilities", []) or [] if ability_usable(r)]
        mine = [r for r in rows if r.get("card") == word] or \
               [r for r in rows if str(r.get("name", "")).casefold() == word.casefold()]
        if index is not None:
            if not isinstance(index, int) or isinstance(index, bool):
                raise refusal(tool, "option", "`index` is a whole number", flag="index")
            mine = [r for r in mine if int(r.get("index", 0) or 0) == index] or \
                ([] if kind == "ability" else [r for r in mine if index == 0])
        if not mine:
            listed = [f"{r.get('name')} {r.get('card')}" + (f" #{r.get('index', 0)}" if kind == "ability" else "")
                      for r in rows]
            known = cards.get(word) or next((c for c in cards.values()
                                             if str(c.get("name", "")).casefold() == word.casefold()), None)
            what = "castable" if kind == "spell" else "usable"
            if known is None:
                near = difflib.get_close_matches(word, sorted({str(c.get("name", "")) for c in cards.values()}), n=3)
                message = f"no card '{word}' in this view"
            elif kind == "spell" and known.get("land"):
                near = []
                message = f"{_named(known)} is a land — play it with referee_play_land"
            else:
                near = []
                message = (f"{_named(known)} is not {what} now" if index is None else
                           f"{_named(known)} has no {what} {kind} #{index} now")
            raise refusal(tool, "cast", message + (f"; {what} now: {', '.join(listed)}" if listed else
                                                   f"; nothing is {what} now"),
                          suggestions=near, **{"castable" if kind == "spell" else "usable": listed})
        by_card: dict = {}
        for row in mine:
            by_card.setdefault(row.get("card"), []).append(row)
        if kind == "ability":
            for handle, rows_ in by_card.items():
                if len(rows_) > 1 and index is None:
                    raise refusal(tool, "option", f"{_named(cards.get(handle), handle)} has "
                                  f"{len(rows_)} usable abilities: give `index` — "
                                  + "; ".join(f"#{r.get('index')} {r.get('cost', '')} {r.get('label', '')}".strip()
                                              for r in rows_), flag="index")
        untapped = [r for r in mine if not (cards.get(r.get("card")) or {}).get("tapped")]
        return (untapped or mine)[0]

    def cast_step(self, game: Game, action: dict, timeout: float, steps: list, refused: list) -> dict:
        """One action of a one-call cast, sent and answered; the refusals
        on the way are collected."""
        steps.append({k: v for k, v in action.items() if k != "seat"})
        game.send(action)
        state = game.advance(timeout, render=False)
        refused += state.get("refused", [])
        return state

    def cast_withdraw(self, game: Game, timeout: float, steps: list, refused: list) -> str:
        """Withdraw an open announcement (or the payment's question):
        `cancel`. '' when it went, the refusal otherwise."""
        now = game.pending
        if now is None:
            return "no decision to withdraw it from"
        options = now.get("options") or {}
        if not options.get("announcement") and now.get("mode") != "choice":
            return ""
        before = len(refused)
        self.cast_step(game, {"op": "cancel", "seat": now.get("seat")}, timeout, steps, refused)
        return refused[-1].get("reason", "refused") if len(refused) > before else ""

    def cast_refused(self, game: Game, cast: dict, stage: str, reason: str, steps: list, refused: list,
                     kind: str = "cast", **more) -> None:
        """Raise the refusal of a one-call cast, with the decision now
        pending (shown, so its journal reaches the client), what was
        sent, what the referee refused, and the mana left floating."""
        cast = {**cast, "result": "refused", "stage": stage, "reason": reason}
        still_open = game.pending is not None and bool((game.pending.get("options") or {}).get("announcement"))
        cast["withdrawn"] = not still_open
        floating = floating_mana(game.pending)
        if floating:
            cast["floating_mana"] = floating
            cast["note"] = "the mana made stays in your pool until the step ends — use it or it burns"
        state: dict = {"game": game.ident, "decisions": game.decisions, "refusals": game.refusals,
                       "cast": cast, "sent": steps}
        if refused:
            state["refused"] = refused
        if game.pending is not None:
            state["decision"] = game.shown()
        if game.result is not None:
            state["result"] = game.result
        self.settle(game)
        envelope = {"tool": "referee_cast", "exit": 2, "kind": kind,
                    "message": f"{cast.get('name') or cast.get('card') or 'the cast'}: {reason}", **more, **state}
        raise ToolError(envelope, None if game.text == "json" else self.answer_text(game, state, game.view))

    def cast_answer(self, game: Game, state: dict, cast: dict, result: str, steps: list, refused: list,
                    note: str = "") -> dict:
        cast = {**cast, "result": result}
        if note:
            cast["note"] = note
        floating = floating_mana(game.pending)
        if floating and result == "open":
            cast["floating_mana"] = floating
        state = dict(state)
        if game.pending is not None and "decision" not in state and not state.get("pending"):
            state["decision"] = game.shown()
        state.setdefault("game", game.ident)
        state["decisions"] = game.decisions
        state["refusals"] = game.refusals
        state["cast"] = cast
        state["sent"] = steps
        if refused:
            state["refused"] = refused
        self.settle(game)
        return self.present(game, state)

    def tool_referee_play_land(self, args: dict) -> dict:
        tool = "referee_play_land"
        game = self.game_of(args)
        if args.get("view"):
            game.view = self.view_of(args)
        until = self.until_of(args)
        decision = self.open_decision(game, tool)
        lands = [r for r in ((decision.get("options") or {}).get("play") or {}).get("lands", []) or []
                 if isinstance(r, dict)]
        word = str(args.get("card") or "").strip()
        chosen = lands[:1] if not word else \
            ([r for r in lands if r.get("card") == word] or
             [r for r in lands if str(r.get("name", "")).casefold() == word.casefold()])[:1]
        if not chosen:
            listed = [f"{r.get('name')} {r.get('card')}" for r in lands]
            raise refusal(tool, "land", (f"'{word}' is not a land you can play now" if word else "no land can be played now")
                          + (f"; playable: {', '.join(listed)}" if listed else
                             f" (decision `{decision.get('mode')}`, step {decision.get('step')})"),
                          game=game.ident, playable=listed)
        action = {"op": "play", "card": chosen[0].get("card"), "seat": decision.get("seat")}
        origin = decision
        game.send(action)
        state = self.after_send(game, until, origin, float(args.get("timeout") or DECISION_TIMEOUT))
        state["action"] = action
        self.settle(game)
        return self.present(game, state)

    # ----- the decision-model menus (0.50.13, tools/decision_menu.py) ------

    def _decision_driver(self, game: Game, args: dict) -> decision_menu.Driver:
        """The game's menu Driver (kept in `game.memory["decide"]`)."""
        if game.result is None and game.error is None and game.pending is None:
            raise refusal("referee", "game", f"game {game.ident} has no decision pending — referee_wait reads on",
                          game=game.ident)
        options = {} if args.get("probe") is None else {"probe": bool(args["probe"])}
        try:
            return decision_menu.attach_game(game, float(args.get("timeout") or DECISION_TIMEOUT), **options)
        except decision_menu.DriverError as exc:
            raise refusal("referee", "game", f"game {game.ident}: {exc}", game=game.ident)

    def _menu_answer(self, game: Game, driver: decision_menu.Driver, state: dict, rich: bool):
        """A menu tool's answer: the menu state, and in the `compact` view
        the board and the menu as numbered lines for the `content`."""
        try:
            state.update(decision_menu.menu_state(driver, rich))
        except decision_menu.DriverError as exc:
            self.settle(game)
            raise refusal("referee", "game", f"game {game.ident}: {exc}", game=game.ident)
        decision = driver.decision
        self.settle(game)
        if game.text == "json":
            return state
        return Answer(state, menu_text(state, decision, driver.journal, self.my_seat(game)))

    def tool_referee_menu(self, args: dict):
        game = self.game_of(args)
        if args.get("view"):
            game.view = self.view_of(args)
        driver = self._decision_driver(game, args)
        return self._menu_answer(game, driver, {"game": game.ident}, bool(args.get("rich")))

    def tool_referee_pick(self, args: dict):
        game = self.game_of(args)
        if args.get("view"):
            game.view = self.view_of(args)
        until = self.until_of(args)   # checked before anything is sent
        driver = self._decision_driver(game, args)
        if driver.done:
            return self._menu_answer(game, driver, {"game": game.ident}, bool(args.get("rich")))
        stop = None
        if until is not None:
            origin = driver.decision
            # the server's own stop rule — every UNTIL value, `mine`/`mine-strict` included
            stop = lambda d: stop_reason(d, until, origin)   # noqa: E731
        try:
            out = driver.pick(args["pick"], until=stop)
        except ValueError as exc:
            menu = [item["id"] for item in driver.menu()]
            raise refusal("referee", "option", str(exc), flag="pick",
                          suggestions=difflib.get_close_matches(str(args["pick"]), menu, n=3), menu=menu)
        except decision_menu.DriverError as exc:
            self.settle(game)
            raise refusal("referee", "game", f"game {game.ident}: {exc}", game=game.ident)
        state: dict = {"game": game.ident, "picked": out["item"]}
        if out["refused"]:
            state["refused"] = out["refused"]
        if until is not None:
            state["stop"], state["passed"], state["until"] = out.get("stop", ""), out.get("passed", 0), until
        return self._menu_answer(game, driver, state, bool(args.get("rich")))

    def tool_referee_view(self, args: dict) -> dict:
        """The pending decision again, in any view, without acting and
        without changing the game's own view (or the delta's base)."""
        game = self.game_of(args)
        mode = self.view_of(args, game.view)
        state: dict = {"game": game.ident, "decisions": game.decisions, "refusals": game.refusals, "view": mode}
        if game.pending is not None:
            state["decision"] = game.render(mode)
        elif game.result is None and game.error is None:
            state["pending"] = True
            state["note"] = "no decision has arrived yet; referee_wait reads on"
        if game.result is not None:
            state["result"] = game.result
        if game.error is not None:
            state["error"] = game.error
        return self.present(game, state, mode)

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
            # Each decision between is answered unseen: `send` keeps its
            # journal for the one shown at the end (2026-10-04).
            game.send(action)
            state = game.advance(timeout, render=False)
            played += 1
            refused += state.get("refused", [])
            if state.get("pending"):
                break
        if game.pending is not None and "decision" not in state and not state.get("pending"):
            state["decision"] = game.shown()
        state["played"] = played
        if refused:
            state["refused"] = refused
        self.settle(game)
        return self.present(game, state)

    def tool_referee_wait(self, args: dict) -> dict:
        game = self.game_of(args)
        if args.get("view"):
            game.view = self.view_of(args)
        if game.pending is not None or game.result is not None or game.error is not None:
            state = game._state([])
            state["hello"] = game.hello
            return self.present(game, state)
        state = game.advance(float(args.get("timeout") or DECISION_TIMEOUT))
        state["hello"] = game.hello
        self.settle(game)
        return self.present(game, state)

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
        return self.present(game, game.summary())

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
                    result = tool_result({"error": exc.envelope}, True, exc.text)
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


def tool_result(payload: dict, is_error: bool, text: str | None = None) -> dict:
    """The `tools/call` result: the payload as `structuredContent`, and as
    `content` its JSON — or, for an `Answer` (a compact-view referee
    answer), its own text."""
    if text is None:
        text = payload.text if isinstance(payload, Answer) else json.dumps(payload, ensure_ascii=False, default=str)
    return {"content": [{"type": "text", "text": text}], "structuredContent": dict(payload), "isError": is_error}


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
