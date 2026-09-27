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
import os
import queue
import re
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
VIEWS = ("brief", "full", "options")
RESULT_LIMIT = 50

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
    "its `options`, `referee_join` sits at a table a person hosts in the "
    "game. `contract` is the whole contract page; `manual` a tool's own help. "
    "Read `play_guide` for MTG rules, fair-information play, combat and deck "
    "building; optionally request one chapter (1-16) instead of the full guide."
)


class ToolError(Exception):
    """A refusal a tool reports as data — the door's envelope, or one
    shaped like it."""

    def __init__(self, envelope: dict):
        super().__init__(envelope.get("message", "refused"))
        self.envelope = envelope


def refusal(tool: str, kind: str, message: str, exit_code: int = 2, **more) -> ToolError:
    body = {"tool": tool, "exit": exit_code, "kind": kind, "message": message}
    body.update(more)
    return ToolError(body)


# --- the deck files, read and written without an engine ----------------

DECK_LINE = re.compile(r"^\s*(\d+)\s*[xX]?\s+(.+?)\s*$")


def parse_deck(text: str) -> dict:
    """The .deck/.dec reading `engine/deck_list.gd` documents: `#` and
    `//` comments (`// NAME: X` names the deck), `name: X`, `4 Card`,
    `4x Card`, `SB: 3 Card`. Lines that are none of these are `errors`;
    the engine's own reading (the `check_deck` tool) is the judge."""
    name = ""
    main: list[dict] = []
    side: list[dict] = []
    errors: list[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("//"):
            body = line[2:].strip()
            if body.upper().startswith("NAME:"):
                name = body[5:].strip()
            continue
        if line.startswith("#"):
            continue
        if line.lower().startswith("name:"):
            name = line[5:].strip()
            continue
        target = main
        if line.upper().startswith("SB:"):
            target = side
            line = line[3:].strip()
        found = DECK_LINE.match(line)
        if not found:
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
            try:
                count = int(row.get("count", 1))
            except (TypeError, ValueError):
                raise refusal(tool, "option", f"`{what}`: a count is a whole number", flag=what)
            name = str(row["name"]).strip()
        elif isinstance(row, str):
            found = DECK_LINE.match(row.strip())
            if not found:
                raise refusal(tool, "option",
                              f"`{what}`: '{row}' is not 'COUNT Card Name'", flag=what)
            count, name = int(found.group(1)), found.group(2)
        else:
            raise refusal(tool, "option", f"`{what}`: a row is 'COUNT Card Name' or {{count, name}}",
                          flag=what)
        if count < 1 or not name:
            raise refusal(tool, "option", f"`{what}`: '{row}' needs a count and a name", flag=what)
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


def render_decision(decision: dict, mode: str) -> dict:
    """One `decision` line for the client: `full` is the referee's own,
    `options` drops the view, `brief` replaces it."""
    if mode == "full":
        return decision
    out = {k: v for k, v in decision.items() if k != "view"}
    if mode == "brief":
        out["brief"] = brief_view(decision.get("view", {}), int(decision.get("seat", 0)))
    return out


# --- the dumb pilot -------------------------------------------------------

def default_answer(decision: dict, memory: dict) -> dict:
    """Keep, order to play, attack with everything, block nothing,
    discard from the front, assign damage as asked, first choice; in a
    main phase play a land, then cast the first castable spell once
    (prepare, autopay, submit) — the referee's own tests' pilot.
    `memory` (`paid`, `tried`, `strikes`) is the game's, so a spell
    refused once is not cast again that step, and a decision the
    referee has already refused an answer to gets the quiet answer
    (cancel, pass, no attackers) — the third refusal concedes."""
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
        return {"op": "attack", "cards": [c["card"] for c in options.get("attack", {}).get("attackable", [])]}
    if mode == "block":
        return {"op": "block", "pairs": []}
    if mode == "discard":
        want = options.get("discard", {})
        return {"op": "discard", "cards": [c["card"] for c in want.get("hand", [])[:int(want.get("count", 0))]]}
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
            targets = []
            for slot in options["announcement"].get("slots", []):
                if len(slot.get("targets", [])) < int(slot.get("min", 0)):
                    return {"op": "cancel"}
                for target in slot["targets"][:int(slot.get("min", 0))]:
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

class Game:
    def __init__(self, ident: str, argv: list[str], view: str, cwd: Path, stderr_path: Path):
        self.ident = ident
        self.argv = argv
        self.view = view
        self.started = time.time()
        self.hello: dict | None = None
        self.pending: dict | None = None
        self.result: dict | None = None
        self.error: dict | None = None
        self.decisions = 0
        self.refusals = 0
        self.memory: dict = {}
        self.lines: queue.Queue = queue.Queue()
        self.closed = False
        stderr_path.parent.mkdir(parents=True, exist_ok=True)
        self.stderr_file = stderr_path.open("w", encoding="utf-8")
        env = dict(os.environ)
        env["SHANDALAR_NO_BANNER"] = "1"
        env["NO_COLOR"] = "1"
        self.proc = subprocess.Popen(argv, cwd=str(cwd), stdin=subprocess.PIPE,
                                     stdout=subprocess.PIPE, stderr=self.stderr_file,
                                     text=True, bufsize=1, encoding="utf-8", env=env)
        self.pump = threading.Thread(target=self._pump, daemon=True)
        self.pump.start()

    def _pump(self) -> None:
        try:
            for line in self.proc.stdout:
                self.lines.put(line)
        finally:
            self.lines.put(None)

    @property
    def running(self) -> bool:
        return self.proc.poll() is None and not self.closed

    def send(self, action: dict) -> None:
        if not self.running or self.proc.stdin is None:
            raise refusal("referee", "game", f"game {self.ident} is over", game=self.ident)
        try:
            self.proc.stdin.write(json.dumps(action, ensure_ascii=False) + "\n")
            self.proc.stdin.flush()
        except (BrokenPipeError, OSError, ValueError) as exc:
            raise refusal("referee", "game", f"game {self.ident}: the pipe closed ({exc})",
                          game=self.ident)

    def advance(self, timeout: float) -> dict:
        """Read lines until a decision, a result or an error; the
        refusals on the way are collected. `pending: true` says nothing
        arrived in `timeout` seconds — call `referee_wait` again."""
        refused: list[dict] = []
        deadline = time.time() + max(0.0, timeout)
        while True:
            left = deadline - time.time()
            if left <= 0:
                return self._state(refused, pending=True)
            try:
                line = self.lines.get(timeout=min(left, 1.0))
            except queue.Empty:
                continue
            if line is None:
                self.closed = True
                if self.result is None and self.error is None:
                    self.error = {"tool": "referee", "exit": self.proc.wait(), "kind": "run",
                                  "message": f"game {self.ident}: the referee ended without a result",
                                  "stderr": self.stderr_tail()}
                self.pending = None
                return self._state(refused)
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
                return self._state(refused)
            kind = record.get("type")
            if kind == "hello":
                self.hello = record
            elif kind == "refused":
                self.refusals += 1
                refused.append(record)
                strikes = self.memory.setdefault("strikes", {})
                strikes[int(record.get("n", -1))] = strikes.get(int(record.get("n", -1)), 0) + 1
            elif kind == "decision":
                if self.pending is None or int(record.get("n", 0)) != int(self.pending.get("n", -1)):
                    self.decisions += 1
                self.pending = record
                return self._state(refused)
            elif kind == "result":
                self.result = record
                self.pending = None
                return self._state(refused)

    def _state(self, refused: list[dict], pending: bool = False) -> dict:
        out: dict = {"game": self.ident, "decisions": self.decisions, "refusals": self.refusals}
        if refused:
            out["refused"] = refused
        if pending:
            out["pending"] = True
            out["note"] = "nothing arrived in time; referee_wait reads on"
        elif self.pending is not None:
            out["decision"] = render_decision(self.pending, self.view)
        if self.result is not None:
            out["result"] = self.result
        if self.error is not None:
            out["error"] = self.error
        return out

    def stderr_tail(self, lines: int = 12) -> list[str]:
        try:
            self.stderr_file.flush()
            text = Path(self.stderr_file.name).read_text(encoding="utf-8", errors="replace")
        except OSError:
            return []
        return text.splitlines()[-lines:]

    def close(self, grace: float = 10.0) -> None:
        if self.proc.stdin is not None:
            try:
                self.proc.stdin.close()
            except OSError:
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
        self.closed = True
        try:
            self.stderr_file.close()
        except OSError:
            pass

    def summary(self) -> dict:
        out = {"game": self.ident, "running": self.running, "view": self.view,
               "decisions": self.decisions, "refusals": self.refusals,
               "seconds": round(time.time() - self.started, 1), "argv": self.argv[1:]}
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


STRING_LIST = {"type": "array", "items": {"type": "string"}}


class Server:
    def __init__(self, door: Path, workspace: Path):
        self.door = door.resolve()
        self.root = self.door.parent
        self.native = self.door.name.lower() == WINDOWS_DOOR.lower()
        self.workspace = workspace if workspace.is_absolute() else (self.root / workspace)
        self.workspace = self.workspace.resolve()
        self.games: dict[str, Game] = {}
        self.next_game = 1
        self.version_cache: str | None = None
        self.tools = self._catalogue()

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

    def run(self, verb: str, args: list[str], timeout: float = DEFAULT_TIMEOUT) -> subprocess.CompletedProcess:
        env = dict(os.environ)
        env["SHANDALAR_NO_BANNER"] = "1"
        env["NO_COLOR"] = "1"
        argv = self.command(verb, args)
        try:
            return subprocess.run(argv, cwd=str(self.root), capture_output=True, text=True,
                                  encoding="utf-8", errors="replace", timeout=timeout,
                                  stdin=subprocess.DEVNULL, env=env)
        except subprocess.TimeoutExpired:
            raise refusal(verb, "timeout", f"{verb} did not finish in {timeout:.0f} s", exit_code=1,
                          argv=argv[1:], timeout=timeout)
        except OSError as exc:
            raise refusal("shandalar", "door", f"the door {self.door} would not run: {exc}", exit_code=3)

    @staticmethod
    def parse_stdout(done: subprocess.CompletedProcess):
        text = done.stdout.strip()
        if not text:
            return None
        try:
            return json.loads(text)
        except ValueError:
            return None

    def quote(self, verb: str, done: subprocess.CompletedProcess, ok=(0,)):
        """The door's JSON, or its refusal raised as one."""
        parsed = self.parse_stdout(done)
        if done.returncode not in ok:
            if isinstance(parsed, dict) and isinstance(parsed.get("error"), dict):
                raise ToolError(parsed["error"])
            tail = [line for line in done.stderr.splitlines() if line.strip()][-8:]
            kind = "godot" if done.returncode == 3 else "run"
            message = tail[-1] if tail else f"{verb} exited {done.returncode}"
            raise refusal(verb, kind, message, exit_code=done.returncode, stderr=tail)
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
                    "`full` the referee's whole LAN view; `options` the legal answers alone",
                    enum=list(VIEWS))
        game = prop("string", "the game id `referee_start` or `referee_join` returned (`g1`)")
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
                       "with its name and card counts read from the file.",
                       {"folder": prop("string", "one folder instead (under the checkout or the "
                                       "workspace), searched recursively")},
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
                        "view": view, "timeout": timeout},
                       self.tool_referee_start, required=["deck_a", "deck_b"]),
            self._tool("referee_join", "Sit at a table a person (or another program) hosts in the "
                       "game — play against a human. Takes the LAN invitation (`sglan1:...`) the "
                       "host's screen shows, or the same-computer access code with `port`. The "
                       "answer arrives when the table starts; until then `pending` is true and "
                       "`referee_wait` reads on. The host sees an ordinary guest.",
                       {"invitation": prop("string", "the invitation or access code"),
                        "deck": prop("string", "the deck this seat brings, as typed, under `decks/` or in the workspace"),
                        "port": prop("integer", "the host's port for an access code (default 17897)"),
                        "name": prop("string", "this seat's nickname at the table"),
                        "wait": prop("integer", "seconds to wait for an open table (default 300)"),
                        "turns": prop("integer", "the duel is a draw past this turn"),
                        "packs": packs, "view": view,
                        "timeout": prop("number", "seconds to wait for the first decision before "
                                        "answering `pending` (default 15)")},
                       self.tool_referee_join, required=["invitation", "deck"]),
            self._tool("referee_act", "Answer the pending decision of a game and return the next "
                       "one (or the `result`). `action` is one of the decision's `options` as the "
                       "wire takes it — `{\"op\":\"pass\"}`, `{\"op\":\"play\",\"card\":\"c3\"}`, "
                       "`{\"op\":\"attack\",\"cards\":[...]}` — or the string `default` for the "
                       "built-in pilot's answer. A `refused` entry means the answer could not be "
                       "applied and the same decision is back; twenty refusals in a row concede.",
                       {"game": game,
                        "action": {"description": "the answer: an object with `op` (the seat is "
                                   "filled in), or `default`", "type": ["object", "string"]},
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
                       "person still thinking).",
                       {"game": game, "view": view, "timeout": timeout},
                       self.tool_referee_wait, required=["game"]),
            self._tool("referee_stop", "End a game: the pipe is closed, the referee writes its "
                       "`result` (`reason: eof`) and exits. A game that already ended answers its "
                       "result.",
                       {"game": game}, self.tool_referee_stop, required=["game"]),
        ]

    @staticmethod
    def _tool(name: str, description: str, properties: dict, handler, required: list[str] | None = None) -> dict:
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
            raise KeyError(name, near)
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
        return tool["handler"](arguments)

    # ----- the small tools ------------------------------------------------

    def tool_status(self, args: dict) -> dict:
        return {"server": SERVER_NAME, "version": self.version(), "door": str(self.door),
                "root": str(self.root), "workspace": str(self.workspace),
                "contract": str(self.root / CONTRACT), "tools": [t["name"] for t in self.tools],
                "games": [g.summary() for g in self.games.values()]}

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
        return self.quote("packs", self.run("packs", []))

    def tool_cards(self, args: dict) -> dict:
        names = self.strings(args["names"], "cards", "names")
        return self.quote("cards", self.run("cards", names))

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
        return self.quote("check", self.run("check", self.check_args(args, decks)))

    def tool_convert_deck(self, args: dict) -> dict:
        source = str(args["input"])
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
            folder = self.inside(args["folder"], "list_decks", "folder")
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
        for folder, label in self.deck_folders(args):
            for path in sorted(folder.rglob("*")):
                if not path.is_file() or path.suffix.lower() not in (".deck", ".dec", ".dck"):
                    continue
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
                decks.append(row)
        return {"decks": decks, "count": len(decks)}

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
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(deck_text(name, main, side), encoding="utf-8")
        out: dict = {"file": self.spoken(target), "name": name,
                     "cards": sum(r["count"] for r in main), "sideboard": sum(r["count"] for r in side)}
        if args.get("check", True):
            check = self.quote("check", self.run("check", self.check_args(args, [str(target)])))
            out["check"] = check
            if isinstance(check, dict):
                out["playable"] = check.get("playable")
        return out

    # ----- the AutoDeck and the Lab ---------------------------------------

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
        timeout = float(args.get("timeout") or DEFAULT_TIMEOUT)
        done = self.run("autodeck", argv, timeout=timeout)
        parsed = self.quote("autodeck", done)
        if args.get("dry_run"):
            return {"plan": parsed, "argv": argv}
        result: dict = {"exit": done.returncode, "out": self.spoken(out), "argv": argv}
        run_file = out / "run.json"
        if run_file.is_file():
            result["run"] = json.loads(run_file.read_text(encoding="utf-8"))
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
            out = None
            if "--out" in argv:
                out = self.inside(argv[argv.index("--out") + 1], tool, "out")
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
        argv.append("--quiet")
        return argv, out

    def run_lab(self, argv: list[str], out: Path | None, args: dict) -> dict:
        timeout = float(args.get("timeout") or DEFAULT_TIMEOUT)
        done = self.run("lab", argv, timeout=timeout)
        if "--dry-run" in argv:
            return {"plan": self.quote("lab", done), "argv": argv}
        parsed = self.quote("lab", done, ok=(0, 4))
        result: dict = {"exit": done.returncode, "argv": argv, "report": done.stdout}
        if done.returncode == 4:
            result["warning"] = "the control pair did not replay game for game — the results are suspect"
        if out is None:
            out = self.out_from_stderr(done.stderr)
        if out is not None:
            result.update(self.read_run(out, int(args.get("limit") or RESULT_LIMIT)))
        elif isinstance(parsed, dict):
            result["stdout"] = parsed
        return result

    def out_from_stderr(self, stderr: str) -> Path | None:
        """The Lab names its default `--out` on stderr; a run without
        `--out` is found there."""
        found = re.findall(r"(?:results?|out(?:put)?)\S*:?\s+(\S*run_\d+\S*)", stderr)
        for text in found:
            path = (self.root / text.strip("'\"")).resolve()
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
        run = json.loads(run_file.read_text(encoding="utf-8"))
        result["run"] = run
        result["next"] = run.get("next")
        for name in ("results.json", "sweep.json"):
            path = out / name
            if path.is_file():
                data = json.loads(path.read_text(encoding="utf-8"))
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
        run = json.loads(run_file.read_text(encoding="utf-8"))
        nxt = run.get("next")
        if not isinstance(nxt, dict) or not nxt.get("argv"):
            return {"out": self.spoken(out), "next": None,
                    "why": "nothing is open — every matchup decided, every delta clear"}
        argv = [str(a) for a in nxt["argv"]]
        target = None
        if "--out" in argv:
            target = self.inside(argv[argv.index("--out") + 1], "lab_next", "out")
        result = self.run_lab(argv + ["--quiet"], target, args)
        result["why"] = nxt.get("why")
        result["from"] = self.spoken(out)
        return result

    # ----- the referee ----------------------------------------------------

    def new_game(self, argv: list[str], view: str) -> Game:
        ident = f"g{self.next_game}"
        self.next_game += 1
        stderr = self.workspace / "games" / f"{ident}.stderr"
        game = Game(ident, self.command("referee", argv), view, self.root, stderr)
        self.games[ident] = game
        return game

    def open_game(self, argv: list[str], view: str, timeout: float) -> dict:
        game = self.new_game(argv, view)
        state = game.advance(timeout)
        if game.error is not None and game.hello is None:
            game.close(grace=2)
            del self.games[game.ident]
            raise ToolError(game.error)
        state["hello"] = game.hello
        if game.result is not None:
            game.close(grace=5)
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
        return self.open_game(argv, self.view_of(args), float(args.get("timeout") or DECISION_TIMEOUT))

    def tool_referee_join(self, args: dict) -> dict:
        argv = ["--join", str(args["invitation"]), "--deck", self.deck_arg(args["deck"])]
        for key in ("port", "name", "wait", "turns", "packs"):
            self.flag(argv, args, key, "--" + key)
        return self.open_game(argv, self.view_of(args), float(args.get("timeout") or 15))

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
        game.send(action)
        state = game.advance(float(args.get("timeout") or DECISION_TIMEOUT))
        state["action"] = action
        if game.result is not None or game.error is not None:
            game.close(grace=5)
        return state

    def tool_referee_autoplay(self, args: dict) -> dict:
        game = self.game_of(args)
        if args.get("view"):
            game.view = self.view_of(args)
        limit = int(args["decisions"]) if args.get("decisions") else None
        timeout = float(args.get("timeout") or DECISION_TIMEOUT)
        played = 0
        refused: list[dict] = []
        state = game._state([])
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
        if game.result is not None or game.error is not None:
            game.close(grace=5)
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
        if game.result is not None or game.error is not None:
            game.close(grace=5)
        return state

    def tool_referee_stop(self, args: dict) -> dict:
        game = self.game_of(args)
        if game.running:
            game.close(grace=1)
            game.advance(10)
        game.close(grace=10)
        return game.summary()

    def shutdown(self) -> None:
        for game in list(self.games.values()):
            if game.running:
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
        raise KeyError(uri)

    def handle(self, message) -> dict | None:
        if not isinstance(message, dict) or message.get("jsonrpc") != "2.0" or "method" not in message:
            ident = message.get("id") if isinstance(message, dict) else None
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
                except KeyError as exc:
                    near = exc.args[1] if len(exc.args) > 1 else []
                    return None if notification else error_response(
                        ident, -32602, f"unknown tool '{name}'", {"suggestions": near, "tools": [t["name"] for t in self.tools]})
                except ToolError as exc:
                    result = tool_result({"error": exc.envelope}, True)
            elif method == "resources/list":
                result = {"resources": self.resources()}
            elif method == "resources/read":
                uri = params.get("uri") if isinstance(params, dict) else None
                try:
                    result = {"contents": [self.read_resource(str(uri))]}
                except KeyError:
                    return None if notification else error_response(ident, -32002, f"unknown resource '{uri}'")
                except ToolError as exc:
                    return None if notification else error_response(ident, -32603, exc.envelope.get("message", "refused"))
            elif method.startswith("notifications/"):
                return None
            else:
                return None if notification else error_response(ident, -32601, f"Method not found: {method}")
        except Exception as exc:  # noqa: BLE001 — the protocol answer is the report
            print(f"shandalar_mcp: {method}: {type(exc).__name__}: {exc}", file=sys.stderr)
            return None if notification else error_response(ident, -32603, f"{type(exc).__name__}: {exc}")
        if notification:
            return None
        return {"jsonrpc": "2.0", "id": ident, "result": result}

    def serve(self, source=None, sink=None) -> int:
        source = source or sys.stdin
        sink = sink or sys.stdout
        try:
            for raw in source:
                line = raw.strip()
                if not line:
                    continue
                try:
                    message = json.loads(line)
                except ValueError:
                    emit(sink, error_response(None, -32700, "Parse error"))
                    continue
                if isinstance(message, list):
                    answers = [a for a in (self.handle(m) for m in message) if a is not None]
                    if answers:
                        emit(sink, answers)
                    continue
                answer = self.handle(message)
                if answer is not None:
                    emit(sink, answer)
        finally:
            self.shutdown()
        return 0


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
    return server.serve()


if __name__ == "__main__":
    sys.exit(main())
