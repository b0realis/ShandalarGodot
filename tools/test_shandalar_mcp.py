#!/usr/bin/env python3
"""Self-test for the MCP server — `tools/shandalar_mcp.py`, the one door's
`mcp` verb (2026-09-27). No network, and no Godot: the server is driven
against a FAKE DOOR written here (a Python script that answers the verbs
with canned JSON and a scripted referee), so the protocol, the tool
catalogue, the argument checks, the deck files, the path rule and the
game session are all tested before an engine would be started. The
last class, `LiveTest`, runs the real door and is skipped unless
`SHANDALAR_MCP_LIVE=1` is set — the gate's
`tests/tools/test_mcp_2026_09_27.gd` sets it.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'
    SHANDALAR_MCP_LIVE=1 python3 -m unittest tools.test_shandalar_mcp.LiveTest

WHAT THIS HOLDS:

  * THE PROTOCOL: `initialize` echoes a known version (and answers the
    latest to an unknown one), notifications get no answer, a line that
    is not JSON gets -32700 with a null id, a method the server does not
    speak -32601, a tool it does not have -32602 with the nearest
    names, a batch is answered as a batch.
  * THE CATALOGUE IS SELF-DESCRIBING: every tool has a description a
    program can act on (forty characters at least), an object schema
    with every property described, `additionalProperties: false`, and
    the required keys named.
  * A TOOL QUOTES THE DOOR: `packs` returns the door's JSON as
    `structuredContent`; a door that refuses comes back as `isError`
    with the envelope untouched; an argument the tool does not take is
    refused with the spellings meant; a path outside the checkout and
    the workspace is refused.
  * THE DECKS: `write_deck` writes the format `engine/deck_list.gd`
    reads and checks it; `read_deck` and `list_decks` read it back.
  * THE LAB AND THE AUTODECK build the line the door takes (`--no-elo`
    unless rated, `--quiet` always, `--dry-run` answering the plan);
    `read_run` and `lab_next` read `run.json`.
  * THE GAME: start returns hello and the first decision, `referee_act`
    answers and returns the next, a refused answer comes back as
    `refused` with the same decision, `default` is the pilot's answer,
    concede ends the game with the `result`, `status` lists it, `stop`
    on a closed game is quiet, an unknown game is refused.
  * PASS-UNTIL (2026-10-03): `referee_act`'s `until` passes priority
    after the answer and stops where a player acts — the fake's `--seed
    31` scripts two turns with every such place: an opponent's spell
    on the stack, their declared attackers, a block, their end step
    with an instant in hand; the named stops `main`, `end`, `turn`,
    `play`; a refusal stops the loop. `view: "delta"` shows what moved.
  * THE KEPT GAME: `keep` makes the fake referee listen on the loopback
    (the real one's handshake file, token and replay in miniature); the
    server's shutdown lets it go, another server's `referee_resume`
    takes it up with the whole journal; a game that ended alone is told
    from its transcript; one whose referee is gone is a `keep` refusal
    and is forgotten. `referee_join` by `table` name, with a `log`.
  * THE PINS: the door and the release dispatcher know the verb, the
    release ships the script, AGENTS.md and the maps name it.
"""

import json
import os
import re
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import shandalar_mcp as mcp  # noqa: E402

TOOLS_DIR = Path(__file__).resolve().parent
ROOT = TOOLS_DIR.parent
SERVER = TOOLS_DIR / "shandalar_mcp.py"
LIVE = os.environ.get("SHANDALAR_MCP_LIVE") == "1"

# The fake door: a Python script with the door's verbs, answering from
# canned JSON. `referee` is a scripted pipe: hello, then one decision a
# line read, a refusal for an op it does not know, a result on concede.
FAKE_DOOR = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
here = Path(__file__).resolve().parent
(here / "calls.log").open("a").write(json.dumps(sys.argv[1:]) + "\n")
args = sys.argv[1:]
verb = args[0] if args else ""
rest = args[1:]

def emit(obj, code=0):
    sys.stdout.write(json.dumps(obj) + "\n"); sys.stdout.flush(); sys.exit(code)

def refuse(tool, message, kind="deck", **more):
    err = {"tool": tool, "exit": 2, "kind": kind, "message": message}; err.update(more)
    emit({"error": err}, 2)

if verb in ("-V", "--version"):
    print("shandalar.sh — Shandalar 9.9.9"); sys.exit(0)
if verb == "--help" or (rest and rest[0] == "--help"):
    print("FAKE HELP for %s" % (verb if verb != "--help" else "door")); sys.exit(0)
if verb == "packs":
    emit({"tool": "lab_query", "query": "packs", "known": ["pack-1"], "available": ["pack-1"], "enabled": [],
          "packs": [{"id": "pack-1", "label": "Pack 1", "available": True, "enabled": False, "cards": 373}]})
if verb == "cards":
    # `--packs`: Teferi's Imp is a Pack 8 card, known only with that pack
    # in play; a `packs_broken` file makes `--packs all` refused (a found
    # pack that cannot be enabled), as lab_query refuses it.
    packs = None
    names = []
    i = 0
    while i < len(rest):
        if rest[i] == "--packs": packs = rest[i + 1]; i += 2; continue
        names.append(rest[i]); i += 1
    if packs == "all" and (here / "packs_broken").is_file():
        refuse("lab_query", "could not enable pack-8", kind="packs", flag="--packs")
    pack8 = packs in ("all", "8", "pack-8")
    rows = [{"name": n, "known": True, "cost": "{R}"} if n == "Lightning Bolt"
            else {"name": n, "known": True, "cost": "{1}{U}", "pack": "pack-8"} if n == "Teferi's Imp" and pack8
            else {"name": n, "known": False, "near": ["Lightning Bolt"]} for n in names]
    emit({"tool": "lab_query", "query": "cards", "packs": packs, "cards": rows})
if verb == "check":
    decks = []
    i = 0
    packs = None
    while i < len(rest):
        if rest[i] == "--packs": packs = rest[i + 1]; i += 2; continue
        if rest[i] == "--format": i += 2; continue
        decks.append(rest[i]); i += 1
    rows = []
    for d in decks:
        p = Path(d)
        if not p.is_file():
            refuse("lab_query", "deck file not found: '%s'" % d, path=d)
        text = p.read_text()
        unknown = ["Bogus Card"] if "Bogus Card" in text else []
        cards = sum(int(l.split()[0]) for l in text.splitlines() if l[:1].isdigit())
        rows.append({"file": d, "cards": cards, "unknown": unknown, "playable": not unknown})
    emit({"tool": "lab_query", "query": "check", "packs": packs, "decks": rows, "playable": all(r["playable"] for r in rows)})
if verb == "convert":
    Path(rest[1]).write_text("converted from %s\n" % rest[0]); print("converted 1 deck"); sys.exit(0)
if verb == "lab" and "--resume" in rest:
    # The real Lab's rule: `--resume OUT` is the whole line, but for the
    # chrome flags that only change how it prints (2026-10-03).
    extra = [a for a in rest if a not in ("--resume", rest[rest.index("--resume") + 1])]
    i = 0
    while i < len(extra):
        if extra[i] in ("--quiet", "--no-banner"):
            i += 1
        elif extra[i] == "--progress" and i + 1 < len(extra):
            i += 2
        else:
            refuse("deck_lab", "--resume takes only the run's folder", kind="option", flag="--resume")
if verb in ("lab", "autodeck"):
    if verb == "lab" and "--progress" in rest and rest[rest.index("--progress") + 1] == "json":
        import time as _t
        for i in range(1, 4):
            sys.stderr.write(json.dumps({"progress": {"done": i, "total": 3, "unit": "games", "elapsed": 0.1 * i}}) + "\n")
            sys.stderr.flush()
            _t.sleep(0.05)
    if "--sleep" in rest:
        import time
        (here / "sleeping.pid").write_text(str(os.getpid()))
        time.sleep(float(rest[rest.index("--sleep") + 1]))
    out = rest[rest.index("--out") + 1] if "--out" in rest else None
    if "--dry-run" in rest:
        emit({"tool": verb, "dry_run": True, "argv": rest, "out": out})
    if verb == "lab" and "--resume" in rest:
        out = rest[rest.index("--resume") + 1]
    if verb == "lab" and any(a == "missing.deck" for a in rest):
        refuse("deck_lab", "deck file not found: 'missing.deck'", path="missing.deck")
    o = Path(out); o.mkdir(parents=True, exist_ok=True)
    nxt = None if "--games" in rest and rest[rest.index("--games") + 1] == "9" else \
        {"why": "one matchup straddles even", "argv": ["--deck-a", "a.deck", "--deck-b", "b.deck", "--games", "9", "--out", out]}
    (o / "run.json").write_text(json.dumps({"tool": verb, "argv": rest, "exit": 0, "next": nxt}))
    if verb == "lab":
        (o / "results.json").write_text(json.dumps({"matchups": [{"a": "a.deck", "b": "b.deck", "wins": 5}] * 3,
                                                    "standings": [{"deck": "a.deck"}]}))
        (o / "report.txt").write_text("REPORT\n"); print("REPORT"); sys.exit(4 if "--sweep" in rest else 0)
    (o / "decklist.txt").write_text("d1.deck\nd2.deck\n"); (o / "d1.deck").write_text("4 Lightning Bolt\n")
    (o / "d2.deck").write_text("4 Lightning Bolt\n"); sys.exit(0)
if verb == "referee":
    import select, socket, secrets, time
    if "--dry-run" in rest:
        emit({"tool": "referee", "dry_run": True, "argv": rest})
    if "--deck-a" in rest and rest[rest.index("--deck-a") + 1] == "missing.deck":
        refuse("referee", "deck file not found: 'missing.deck'", path="missing.deck")
    def opt(flag, default=None):
        return rest[rest.index(flag) + 1] if flag in rest else default
    joined = "--join" in rest or "--table" in rest
    hosted = "--host" in rest
    hello = {"type": "hello", "tool": "referee", "protocol": 1, "version": "9.9.9", "seed": int(opt("--seed", "7")),
             "rules": opt("--rules", "modern_mana_burn"),
             "seats": [{"seat": 0, "player": "agent", "name": "Agent", "deck": "A"}, {"seat": 1, "player": "wizard", "name": "Wizard", "deck": "B"}]}
    if joined:
        hello["table"] = {"host": "Someone"}
        if "--table" in rest:
            hello["table"]["name"] = opt("--table")
    if hosted:
        hello["table"] = {"id": "r1", "name": opt("--host"), "seat": 0, "hosted": True}
    if joined or hosted:
        if "--log" in rest:
            hello["log"] = opt("--log")
    # The hosted table's own line, said before hello (the real referee
    # says it once the room exists).
    table = ({"type": "table", "id": "r1", "name": opt("--host"), "access": opt("--access", "open"),
              "host": opt("--name", "Agent"), "address": "127.0.0.1", "port": int(opt("--port", "17897")) or 17897,
              "invitation": "sglan1:fake", "discovery": True} if hosted else None)

    class Keep:
        """The kept game of the real referee, in miniature: a loopback
        server, the handshake file, the token, the replay for a client
        that comes back, the idle clock (capped so a forgotten fake ends)."""
        def __init__(self, path, idle):
            self.srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.srv.bind(("127.0.0.1", 0)); self.srv.listen(4)
            self.token = secrets.token_hex(16)
            self.peer = None; self.buf = b""
            self.idle = idle; self.idle_since = time.monotonic()
            self.awaiting = False; self.finished = False
            self.hello = None; self.table = None; self.decision = None; self.whole = []
            self.decisions = 0; self.refusals = 0
            part = Path(path + ".part")
            part.write_text(json.dumps({"port": self.srv.getsockname()[1], "token": self.token, "pid": os.getpid(),
                                        "version": "9.9.9", "started": "now"}))
            os.replace(part, path)
        def send(self, text):
            if self.peer is not None:
                try: self.peer.sendall((text + "\n").encode("utf-8"))
                except OSError: self.drop()
        def drop(self):
            try: self.peer.close()
            except OSError: pass
            self.peer = None; self.buf = b""; self.idle_since = time.monotonic()
        def seat(self):
            conn, _ = self.srv.accept()
            conn.settimeout(5)
            knock = b""
            try:
                while b"\n" not in knock:
                    chunk = conn.recv(4096)
                    if not chunk: break
                    knock += chunk
            except OSError:
                knock = b""
            first, _, rest_bytes = knock.partition(b"\n")
            try: parsed = json.loads(first or b"{}")
            except ValueError: parsed = {}
            if not isinstance(parsed, dict) or parsed.get("token") != self.token:
                sys.stderr.write("fake referee: a connection without the token was dropped\n"); conn.close(); return
            if self.peer is not None: self.drop()
            conn.settimeout(None)
            self.peer = conn; self.buf = rest_bytes
            if self.table is not None: self.send(json.dumps(self.table))
            if self.hello is not None: self.send(json.dumps(self.hello))
            self.send(json.dumps({"type": "resume", "decisions": self.decisions, "refusals": self.refusals,
                                  "awaiting": self.awaiting, "n": self.decision["n"] if self.awaiting else 0,
                                  "finished": self.finished}))
            if self.awaiting:
                again = dict(self.decision); v = dict(again["view"]); v["journal"] = list(self.whole); again["view"] = v
                self.send(json.dumps(again))
        def read_line(self):
            while True:
                if b"\n" in self.buf:
                    line, self.buf = self.buf.split(b"\n", 1)
                    return line.decode("utf-8", "replace")
                watch = [self.srv] + ([self.peer] if self.peer is not None else [])
                ready, _, _ = select.select(watch, [], [], 0.2)
                if self.srv in ready: self.seat()
                if self.peer is not None and self.peer in ready:
                    try: data = self.peer.recv(65536)
                    except OSError: data = b""
                    if not data: self.drop()
                    else: self.buf += data
                if self.peer is None and self.awaiting and time.monotonic() - self.idle_since >= self.idle:
                    return None

    keep = Keep(opt("--listen"), min(int(opt("--idle", "1800")), 30)) if "--listen" in rest else None
    def out(rec):
        text = json.dumps(rec)
        if keep is not None:
            kind = rec.get("type")
            if kind == "hello": keep.hello = rec
            elif kind == "table": keep.table = rec
            elif kind == "decision":
                keep.decision = rec; keep.decisions = rec["n"] + 1
                for entry in rec["view"].get("journal", []):
                    if entry not in keep.whole: keep.whole.append(entry)
            elif kind == "refused": keep.refusals += 1
            keep.send(text)
            if kind == "decision":
                keep.awaiting = True
                if keep.peer is None: keep.idle_since = time.monotonic()
            elif kind == "result": keep.finished = True
        sys.stdout.write(text + "\n"); sys.stdout.flush()
    def next_line():
        if keep is not None:
            line = keep.read_line()
            return "idle" if line is None else line
        line = sys.stdin.readline()
        return "eof" if line == "" else line
    # A joined table says hello when the duel starts — `--wait 77` is
    # the test's slow host; a hosted one says its table line first and
    # `--wait 77` is the guest who takes their time.
    if table is not None:
        out(table)
    if (joined or hosted) and "--wait" in rest and opt("--wait") == "77":
        # (a kept game seats the client that knocks meanwhile, as the
        # real referee does while the lobby is waited on)
        until = time.monotonic() + 3
        while time.monotonic() < until:
            if keep is None:
                time.sleep(0.2); continue
            ready, _, _ = select.select([keep.srv], [], [], 0.2)
            if keep.srv in ready: keep.seat()
    out(hello)
    view = {"turn": 1, "step": "UPKEEP", "active": 0, "actor": 0, "mode": "opening", "stack": [],
            "hand": [{"id": "c1", "name": "Mountain", "land": True}, {"id": "c2", "name": "Lightning Bolt", "rules": "3 damage"}],
            "players": [{"seat": 0, "deck_name": "A", "life": 20, "hand_count": 7, "library_count": 53, "battlefield": [], "graveyard": [], "exile": []},
                        {"seat": 1, "deck_name": "B", "life": 20, "hand_count": 7, "library_count": 53, "battlefield": [{"id": "c9", "name": "Grizzly Bears", "creature": True, "power": 2, "toughness": 2, "rules": "", "keywords": []}], "graveyard": [], "exile": []}],
            "journal": [{"text": "Toss: seat 0 plays first", "turn": 1}], "presentation": {"cards": [{"id": "c2", "castable": True, "abilities": [{"kind": "spell", "cost": "{R}", "index": 0}]}]}, "winner": -1}
    decisions = [
        {"mode": "opening", "options": {"mode": "opening", "concede": True, "keep": {"op": "keep"}, "order": {"op": "order", "play": [True, False]}}},
        {"mode": "priority", "options": {"mode": "priority", "concede": True, "pass": {"op": "pass"}, "play": {"op": "play", "lands": [{"card": "c1", "name": "Mountain"}]}, "prepare": {"op": "prepare", "casts": [], "abilities": []}}},
        {"mode": "priority", "options": {"mode": "priority", "concede": True, "pass": {"op": "pass"}, "play": {"op": "play", "lands": []}, "prepare": {"op": "prepare", "casts": [{"card": "c2", "name": "Lightning Bolt", "x": False}], "abilities": []}}},
        {"mode": "priority", "options": {"mode": "priority", "concede": True, "pass": {"op": "pass"}, "play": {"op": "play", "lands": []}, "prepare": {"op": "prepare", "casts": [], "abilities": []}}},
    ]
    step = ("MAIN1", "MAIN1", "MAIN1", "MAIN2")
    # `--seed 31`: a scripted stretch of two turns for the pass-until
    # loop — every place a player reacts, in order (see stop_reason).
    SEQ31 = [
        {"turn": 1, "step": "UPKEEP", "mode": "opening", "active": 0},
        {"turn": 1, "step": "MAIN1", "mode": "priority", "active": 0, "lands": True},
        {"turn": 1, "step": "DECLARE_BLOCKERS", "mode": "priority", "active": 0, "played": True},
        {"turn": 1, "step": "END", "mode": "priority", "active": 0, "played": True},
        {"turn": 2, "step": "UPKEEP", "mode": "priority", "active": 1, "respond": True, "played": True},
        {"turn": 2, "step": "MAIN1", "mode": "priority", "active": 1, "respond": True, "played": True,
         "stack": [{"id": "c8", "name": "Grizzly Bears", "controller": 1}]},
        {"turn": 2, "step": "COMBAT_BEGIN", "mode": "priority", "active": 1, "played": True},
        {"turn": 2, "step": "DECLARE_ATTACKERS", "mode": "priority", "active": 1, "respond": True, "played": True, "attacking": True},
        {"turn": 2, "step": "DECLARE_BLOCKERS", "mode": "block", "active": 1, "played": True, "attacking": True},
        {"turn": 2, "step": "END", "mode": "priority", "active": 1, "respond": True, "played": True, "life": 18},
        {"turn": 3, "step": "MAIN1", "mode": "priority", "active": 0, "played": True, "life": 18},
        {"turn": 3, "step": "MAIN2", "mode": "priority", "active": 0, "played": True, "life": 18},
    ]
    # `--seed 33`: the smart pass (`until: "mine"`, 2026-10-04) — the
    # options say what the seat holds: a sorcery is never listed on the
    # opponent's turn, an exhausted once-per-turn ability is not listed
    # (the referee's lists are usable-only), a castable instant is.
    BOLT = [{"card": "c2", "name": "Lightning Bolt", "x": False}]
    SEQ33 = [
        {"turn": 1, "step": "UPKEEP", "mode": "opening", "active": 0},
        {"turn": 1, "step": "MAIN1", "mode": "priority", "active": 0, "lands": True, "casts": []},
        {"turn": 1, "step": "MAIN2", "mode": "priority", "active": 0, "played": True, "casts": []},
        {"turn": 1, "step": "END", "mode": "priority", "active": 0, "played": True, "casts": []},
        {"turn": 2, "step": "UPKEEP", "mode": "priority", "active": 1, "played": True, "casts": []},
        {"turn": 2, "step": "MAIN1", "mode": "priority", "active": 1, "played": True, "casts": [],
         "stack": [{"id": "c8", "name": "Grizzly Bears", "controller": 1}]},
        {"turn": 2, "step": "DECLARE_ATTACKERS", "mode": "priority", "active": 1, "respond": True, "played": True,
         "attacking": True, "casts": BOLT},
        {"turn": 2, "step": "DECLARE_BLOCKERS", "mode": "block", "active": 1, "played": True, "attacking": True},
        {"turn": 2, "step": "END", "mode": "priority", "active": 1, "respond": True, "played": True, "casts": [],
         "life": 18},
        {"turn": 3, "step": "MAIN1", "mode": "priority", "active": 0, "played": True, "life": 18, "casts": BOLT},
    ]
    scripted = hello["seed"] in (31, 33)
    if hello["seed"] == 33:
        SEQ31 = SEQ33
    n = 0
    refusals = 0
    def decision():
        if scripted:
            if n >= len(SEQ31):
                return False
            row = SEQ31[n]
            v = json.loads(json.dumps(view))
            v["turn"] = row["turn"]; v["step"] = row["step"]; v["mode"] = row["mode"]; v["active"] = row["active"]; v["actor"] = 0
            v["stack"] = row.get("stack", [])
            if row.get("played"):
                v["hand"] = [v["hand"][1]]; v["players"][0]["battlefield"] = [{"id": "c1", "name": "Mountain", "land": True}]
            v["players"][0]["life"] = row.get("life", 20)
            if row.get("attacking"):
                v["players"][1]["battlefield"][0]["attacking"] = True
            v["journal"] = [{"text": "n%d: %s" % (n, row["step"]), "turn": row["turn"], "serial": n}]
            if row["mode"] == "opening":
                options = decisions[0]["options"]
            elif row["mode"] == "block":
                options = {"mode": "block", "concede": True, "block": {"op": "block", "attackers": [{"card": "c9", "name": "Grizzly Bears"}], "blockers": []}}
            else:
                options = {"mode": "priority", "concede": True, "pass": {"op": "pass"}, "respond": bool(row.get("respond")),
                           "play": {"op": "play", "lands": [{"card": "c1", "name": "Mountain"}] if row.get("lands") else []},
                           "prepare": {"op": "prepare", "casts": row["casts"] if "casts" in row else ([{"card": "c2", "name": "Lightning Bolt", "x": False}] if row.get("respond") else []), "abilities": []}}
            rec = {"type": "decision", "n": n, "seat": 0, "turn": row["turn"], "step": row["step"], "mode": row["mode"],
                   "options": options, "view": v}
        else:
            v = dict(view); v["step"] = step[min(n, 3)]; v["mode"] = decisions[min(n, 3)]["mode"]
            rec = {"type": "decision", "n": n, "seat": 0, "turn": 1, "step": v["step"], "mode": v["mode"],
                   "options": decisions[min(n, 3)]["options"], "view": v}
        out(rec)
        return True
    def finish(winner, reason):
        if "--log" in rest:
            Path(opt("--log")).write_text("".join("%s\n" % e["text"] for e in (keep.whole if keep else [])) or "the fake duel's log\n")
        out({"type": "result", "winner": winner, "reason": reason, "turns": 1, "decisions": n + (1 if reason == "concede" else 0), "refusals": refusals})
        sys.exit(0)
    if hello["seed"] == 41:
        # THE CAST TABLE (2026-10-04): one main phase with the wire's own
        # announcement — prepare, autopay, submit, cancel, a payment's
        # colour question — for the one-call `referee_cast`. The referee
        # refuses an unpayable cost BEFORE it taps (Fireball X=5, Healing
        # Salve with no white source); Knight of Valor's once-a-turn
        # ability is offered although it was used (the old phantom): its
        # payment taps, its submission is refused, the mana floats.
        T = {"n": 0, "refusals": 0, "step": "MAIN1", "pool": [0, 0, 0, 0, 0, 0], "ann": None, "choice": False,
             "stack": [], "life": [20, 20], "journal": [], "serial": 0, "land_played": False}
        hand = [{"id": "c2", "name": "Lightning Bolt", "cost": "{R}", "need": 1, "instant": True,
                 "rules": "Lightning Bolt deals 3 damage to any target."},
                {"id": "c5", "name": "Fireball", "cost": "{X}{R}", "x": True, "need": 1},
                {"id": "c6", "name": "Chromatic Sphere", "cost": "{1}", "need": 1, "asks": True},
                {"id": "c7", "name": "Healing Salve", "cost": "{W}", "need": 99, "modes": ["Gain 3 life", "Prevent 3 damage"],
                 "usable": [1]},
                {"id": "c13", "name": "Mountain", "land": True}]
        board = [[{"id": "c1", "name": "Mountain", "land": True}, {"id": "c3", "name": "Mountain", "land": True},
                  {"id": "c4", "name": "Knight of Valor", "creature": True, "power": 2, "toughness": 2},
                  {"id": "c14", "name": "Holy Strength", "attached": "c4"}],
                 [{"id": "c9", "name": "Grizzly Bears", "creature": True, "power": 2, "toughness": 2},
                  {"id": "c10", "name": "Grizzly Bears", "creature": True, "power": 2, "toughness": 2},
                  {"id": "c11", "name": "Serra Angel", "creature": True, "power": 4, "toughness": 4, "tapped": True}]]
        phased = [[], [{"id": "c12", "name": "Teferi's Imp", "creature": True, "power": 1, "toughness": 1}]]
        grave = [[], []]
        def say(text):
            T["serial"] += 1
            T["journal"].append({"text": text, "serial": T["serial"]})
        def card(handle):
            for c in hand + board[0] + board[1]:
                if c["id"] == handle: return c
            return None
        def label(c):
            mine = any(x is c for x in board[0])
            return "%s — %s%s" % (c["name"], "yours" if mine else "opponent's", " (tapped)" if c.get("tapped") else "")
        def announce(source, kind, x, mode):
            players = [("player", "0", "You"), ("player", "1", "Opponent")]
            creatures = [("card", c["id"], label(c)) for c in board[0] + board[1] if c.get("creature")]
            if kind == "ability":
                slots = []
            elif source["id"] == "c2":
                slots = [("target creature or player", 1, 1, 0, players + creatures)]
            elif source["id"] == "c5":
                slots = [("divide X damage among any number of creatures and/or players", 1, 6, x, players + creatures)]
            elif source["id"] == "c7":
                slots = [("target player", 1, 1, 0, players)] if mode == 0 else [("target creature or player", 1, 1, 0, players + creatures)]
            else:
                slots = []
            refs, out_slots, k = [], [], 0
            for (text, lo, hi, divided, rows) in slots:
                targets = []
                for (rk, rid, rl) in rows:
                    token = "t%d" % k; k += 1
                    targets.append({"id": token, "label": rl})
                    refs.append({"token": token, "ref": {"kind": rk, "id": rid, "amount": 0}})
                out_slots.append({"label": text, "kind": 2, "min": lo, "max": hi, "divided": divided, "targets": targets})
            return {"name": source["name"], "kind": kind, "x": x, "slots": out_slots}, refs
        def untapped():
            return [c for c in board[0] if c.get("land") and not c.get("tapped")]
        def castable(c):
            return (T["step"] == "MAIN1" and not T["stack"]) or (bool(c.get("instant")) and T["step"] != "DONE")
        def emit_decision():
            ann = T["ann"]
            pres_cards = []
            for c in hand:
                if not c.get("land"):
                    pres_cards.append({"id": c["id"], "castable": True, "flags": {},
                                       "abilities": [{"kind": "spell", "index": 0, "cost": c["cost"], "budget": 2 if c.get("x") else 0}]})
            pres_cards.append({"id": "c4", "castable": False, "flags": {}, "abilities": [{"kind": "ability", "index": 1, "cost": "{1}", "budget": 0}]})
            pres_cards.append({"id": "c12", "castable": False, "flags": {"phased_out": True, "phased_indirectly": False}, "abilities": []})
            refs = []
            if ann is not None:
                ann_view, refs = announce(card(ann["card"]), ann["kind"], ann["x"], ann["mode"])
            else:
                ann_view = {}
            mode = "choice" if T["choice"] else "priority"
            hand_view = [dict(c, rules=c.get("rules", ""), playable=bool(c.get("land")) and not T["land_played"]) for c in hand]
            v = {"turn": 3, "step": T["step"], "active": 0, "actor": 0, "mode": mode, "winner": -1,
                 "stack": list(T["stack"]), "hand": hand_view, "discard_count": 0, "damage_request": {},
                 "choice": ({"prompt": "Choose a color of mana", "source": "Chromatic Sphere", "information": [],
                             "options": ["White", "Blue", "Black", "Red", "Green"], "count": 1, "cancel": True}
                            if T["choice"] else {}),
                 "announcement": ann_view, "information": [], "specials": [],
                 "players": [{"seat": 0, "deck_name": "A", "life": T["life"][0], "hand_count": len(hand), "library_count": 40,
                              "mana": sum(T["pool"]), "mana_colors": list(T["pool"]),
                              "battlefield": [dict(c, controller=0) for c in board[0]], "graveyard": grave[0], "exile": [],
                              "phased_out": [dict(c, controller=0) for c in phased[0]]},
                             {"seat": 1, "deck_name": "B", "life": T["life"][1], "hand_count": 5, "library_count": 40,
                              "mana": 0, "mana_colors": [0] * 6,
                              "battlefield": [dict(c, controller=1) for c in board[1]], "graveyard": grave[1], "exile": [],
                              "phased_out": [dict(c, controller=1) for c in phased[1]]}],
                 "journal": list(T["journal"]),
                 "presentation": {"cards": pres_cards, "targets": refs, "phase_holds": [],
                                  "draft": ({"card": ann["card"], "kind": ann["kind"], "index": ann["index"], "x": ann["x"],
                                             "mode": ann["mode"], "reachable": True} if ann else {})}}
            T["journal"] = []
            if mode == "choice":
                options = {"mode": "choice", "concede": True, "cancel": {"op": "cancel"},
                           "choice": {"op": "choice", "prompt": v["choice"]["prompt"], "options": v["choice"]["options"], "count": 1}}
            elif ann is not None:
                options = {"mode": "priority", "concede": True, "announcement": ann_view, "draft": v["presentation"]["draft"],
                           "autopay": {"op": "autopay"}, "submit": {"op": "submit"}, "cancel": {"op": "cancel"}}
            else:
                casts = [{"card": c["id"], "name": c["name"], "index": 0, "label": "Cast " + c["name"], "x": bool(c.get("x")),
                          "modes": c.get("modes", []), "budget": 2 if c.get("x") else 0,
                          "usable_modes": c.get("usable", list(range(len(c.get("modes", [])))))}
                         for c in hand if not c.get("land") and castable(c)]
                options = {"mode": "priority", "concede": True, "pass": {"op": "pass"}, "respond": True,
                           "play": {"op": "play", "lands": [{"card": c["id"], "name": c["name"]} for c in hand
                                                            if c.get("land") and not T["land_played"] and not T["stack"]]},
                           "prepare": {"op": "prepare", "casts": casts,
                                       "abilities": [{"card": "c4", "name": "Knight of Valor", "index": 1, "label": "{1}: first strike",
                                                      "cost": "{1}", "budget": 0}]},
                           "mana": {"op": "mana", "sources": [{"card": c["id"], "name": c["name"], "index": 0, "label": "{T}: add {R}"}
                                                              for c in untapped()]},
                           "special": {"op": "special", "specials": []}}
            out({"type": "decision", "n": T["n"], "seat": 0, "turn": 3, "step": T["step"], "mode": mode,
                 "options": options, "view": v})
        def refuse_action(reason, action):
            T["refusals"] += 1
            out({"type": "refused", "n": T["n"], "seat": 0, "reason": reason, "action": action, "left": 19})
        def apply(action):
            op = action.get("op")
            ann = T["ann"]
            if T["choice"]:
                if op == "choice":
                    T["choice"] = False; T["pool"][int(action["picks"][0])] += 1; say("Chromatic Sphere makes mana")
                    return ""
                if op == "cancel":
                    T["choice"] = False; T["ann"] = None
                    return ""
                return "Answer the pending question first."
            if op == "prepare":
                c = card(action.get("card"))
                if set(action) != {"op", "card", "kind", "index", "x", "mode"}:
                    return "op 'prepare' takes exactly the keys op, card, kind, index, x, mode"
                if action["kind"] == "ability":
                    if action["card"] != "c4" or action["index"] != 1: return "This action is unavailable."
                elif c is None or c not in hand or c.get("land") or not castable(c):
                    return "This action is unavailable."
                elif (not c.get("x") and action["x"]) or action["mode"] >= max(1, len(c.get("modes", []))):
                    return "Invalid mode or X."
                T["ann"] = {"card": action["card"], "kind": action["kind"], "index": action["index"], "x": action["x"], "mode": action["mode"]}
                return ""
            if op == "autopay":
                if ann is None: return "No announcement is waiting."
                need = 1 if ann["kind"] == "ability" else card(ann["card"])["need"] + ann["x"]
                if need > len(untapped()) + sum(T["pool"]):
                    return "not enough mana for %s" % card(ann["card"])["name"]
                for land in untapped()[:max(0, need - sum(T["pool"]))]:
                    land["tapped"] = True; T["pool"][3 if ann["kind"] == "spell" else 5] += 1
                if ann["kind"] == "spell" and card(ann["card"]).get("asks"):
                    T["pool"] = [0] * 6
                    T["choice"] = True
                return ""
            if op == "submit":
                if ann is None: return "No announcement is waiting."
                ann_view, refs = announce(card(ann["card"]), ann["kind"], ann["x"], ann["mode"])
                tokens = {r["token"]: r for r in refs}
                labels = {}
                for slot in ann_view["slots"]:
                    for t in slot["targets"]: labels[t["id"]] = t["label"]
                for pair in action.get("targets", []):
                    if pair[0] not in tokens: return "Target unavailable."
                if ann["kind"] == "ability":
                    return "Knight of Valor: activate only once each turn"
                total = len(action.get("targets", []))
                for slot in ann_view["slots"]:
                    if not slot["min"] <= total <= slot["max"]: return "choose %d to %d targets" % (slot["min"], slot["max"])
                    if slot["divided"] and sum(p[1] for p in action["targets"]) != slot["divided"]: return "divide the whole amount"
                c = card(ann["card"])
                if sum(T["pool"]) < c["need"] + ann["x"]: return "not enough mana for %s" % c["name"]
                T["pool"] = [0] * 6
                hand.remove(c)
                T["stack"].append({"name": c["name"], "controller": 0, "details": "Spell", "x": ann["x"],
                                   "targets": [labels[p[0]] for p in action.get("targets", [])], "aim": [tokens[p[0]]["ref"]["id"] for p in action.get("targets", [])]})
                T["ann"] = None
                say("Agent casts %s" % c["name"])
                return ""
            if op == "cancel":
                T["ann"] = None
                return ""
            if op == "play":
                c = card(action.get("card"))
                if c is None or not c.get("land") or c not in hand or T["land_played"]: return "You can't play that land now."
                hand.remove(c); board[0].append(dict(c)); T["land_played"] = True; say("Agent plays Mountain")
                return ""
            if op == "pass":
                if ann is not None: return "Finish or cancel the announcement first."
                if T["stack"]:
                    top = T["stack"].pop()
                    say("%s resolves" % top["name"])
                    for aim in top["aim"]:
                        if aim == "1": T["life"][1] -= 3
                        for c in list(board[1]):
                            if c["id"] == aim: board[1].remove(c); grave[1].append({"id": c["id"], "name": c["name"]})
                    return ""
                T["step"] = {"MAIN1": "MAIN2", "MAIN2": "END"}.get(T["step"], "DONE")
                return ""
            return "unknown op '%s'" % op
        emit_decision()
        while True:
            line = next_line()
            if line in ("eof", "idle"):
                out({"type": "result", "winner": 1, "reason": line, "turns": 3, "decisions": T["n"], "refusals": T["refusals"]}); sys.exit(0)
            try:
                action = json.loads(line)
            except ValueError:
                action = {}
            action.pop("seat", None)
            if action.get("op") == "concede":
                out({"type": "result", "winner": 1, "reason": "concede", "turns": 3, "decisions": T["n"] + 1, "refusals": T["refusals"]}); sys.exit(0)
            reason = apply(action)
            if reason:
                refuse_action(reason, action)
            else:
                T["n"] += 1
                if T["step"] == "DONE":
                    out({"type": "result", "winner": 0, "reason": "concluded", "turns": 3, "decisions": T["n"], "refusals": T["refusals"]}); sys.exit(0)
            emit_decision()
    decision()
    while True:
        line = next_line()
        if line in ("eof", "idle"):
            finish(1, line)
        try:
            action = json.loads(line)
        except ValueError:
            action = {}
        op = action.get("op")
        if op == "concede":
            finish(1, "concede")
        if op not in ("keep", "order", "pass", "play", "prepare", "autopay", "submit", "cancel", "attack", "block"):
            refusals += 1
            out({"type": "refused", "n": n, "seat": 0, "reason": "unknown op '%s'" % op, "action": action, "left": 19})
            decision(); continue
        n += 1
        if (not scripted and n >= 6) or not decision():
            finish(0, "concluded")
refuse("shandalar", "unknown verb '%s'" % verb, kind="verb")
'''


class Client:
    """One server process on a pipe; `ask` sends a request and reads
    its answer, `notify` sends a notification and expects silence."""

    def __init__(self, door: Path, workspace: Path):
        self.proc = subprocess.Popen([sys.executable, str(SERVER), "--door", str(door), "--workspace", str(workspace)],
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                     text=True, bufsize=1, encoding="utf-8", cwd=str(ROOT))
        self.next_id = 1
        self.lines: list[str] = []
        self.lock = threading.Condition()
        self.reader = threading.Thread(target=self._pump, daemon=True)
        self.reader.start()

    def _pump(self):
        for line in self.proc.stdout:
            with self.lock:
                self.lines.append(line)
                self.lock.notify_all()
        with self.lock:
            self.lines.append("")
            self.lock.notify_all()

    def raw(self, text: str) -> None:
        self.proc.stdin.write(text if text.endswith("\n") else text + "\n")
        self.proc.stdin.flush()

    def line(self, timeout: float = 30) -> str:
        with self.lock:
            deadline = time.time() + timeout
            while not self.lines:
                left = deadline - time.time()
                if left <= 0:
                    raise AssertionError("no answer from the server in %.0f s" % timeout)
                self.lock.wait(left)
            return self.lines.pop(0)

    def has_line(self, wait: float = 0.5) -> bool:
        with self.lock:
            self.lock.wait_for(lambda: bool(self.lines), wait)
            return bool(self.lines)

    def ask(self, method: str, params=None, timeout: float = 30):
        ident = self.next_id
        self.next_id += 1
        message = {"jsonrpc": "2.0", "id": ident, "method": method}
        if params is not None:
            message["params"] = params
        self.raw(json.dumps(message))
        answer = json.loads(self.line(timeout))
        assert answer.get("id") == ident, answer
        return answer

    def notify(self, method: str, params=None) -> None:
        message = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            message["params"] = params
        self.raw(json.dumps(message))

    def call(self, name: str, arguments=None, timeout: float = 60) -> dict:
        answer = self.ask("tools/call", {"name": name, "arguments": arguments or {}}, timeout)
        assert "result" in answer, answer
        return answer["result"]

    def payload(self, name: str, arguments=None, timeout: float = 60) -> dict:
        result = self.call(name, arguments, timeout)
        assert not result.get("isError"), result
        return result["structuredContent"]

    def close(self) -> str:
        try:
            self.proc.stdin.close()
        except OSError:
            pass
        try:
            self.proc.wait(timeout=20)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait()
        stderr = self.proc.stderr.read()
        self.reader.join(timeout=5)
        for pipe in (self.proc.stdout, self.proc.stderr):
            try:
                pipe.close()
            except OSError:
                pass
        return stderr


class FakeDoorTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="shandalar-mcp-")
        cls.home = Path(cls.tmp.name)
        cls.door = cls.home / "shandalar.sh"
        cls.door.write_text(FAKE_DOOR, encoding="utf-8")
        cls.door.chmod(0o755)
        (cls.home / "AGENTS.md").write_text("# The contract\n\n## The MCP server\n", encoding="utf-8")
        cls.guide = "# Play guide\n\n## Contents\n\n" + "".join(
            f"## {chapter}. Chapter {chapter}\n\nLesson {chapter}.\n\n"
            for chapter in range(1, 17))
        (cls.home / "agentic-playgude-mtg.md").write_text(cls.guide, encoding="utf-8")
        decks = cls.home / "decks" / "tournament"
        decks.mkdir(parents=True)
        (decks / "burn.deck").write_text("// NAME: Burn\n4 Lightning Bolt\n20 Mountain\nSB: 3 Red Elemental Blast\n", encoding="utf-8")
        (cls.home / "decks" / "old.dck").write_text("MicroProse bytes\n", encoding="utf-8")
        cls.workspace = cls.home / "ws"
        cls.client = Client(cls.door, cls.workspace)
        init = cls.client.ask("initialize", {"protocolVersion": "2025-03-26", "capabilities": {},
                                             "clientInfo": {"name": "test", "version": "0"}})
        cls.init = init
        cls.client.notify("notifications/initialized")

    @classmethod
    def tearDownClass(cls):
        cls.stderr = cls.client.close()
        cls.tmp.cleanup()

    def calls(self) -> list[list[str]]:
        log = self.home / "calls.log"
        if not log.is_file():
            return []
        return [json.loads(line) for line in log.read_text(encoding="utf-8").splitlines() if line.strip()]

    # --- the protocol -------------------------------------------------------

    def test_initialize(self):
        result = self.init["result"]
        self.assertEqual(result["protocolVersion"], "2025-03-26")
        self.assertEqual(result["serverInfo"]["name"], "shandalar")
        self.assertEqual(result["serverInfo"]["version"], "9.9.9")
        self.assertIn("tools", result["capabilities"])
        self.assertIn("resources", result["capabilities"])
        self.assertIn("referee_start", result["instructions"])
        self.assertIn("write_deck", result["instructions"])
        self.assertIn("play_guide", result["instructions"])

    def test_initialize_unknown_version_answers_latest(self):
        answer = self.client.ask("initialize", {"protocolVersion": "1999-01-01"})
        self.assertEqual(answer["result"]["protocolVersion"], mcp.LATEST_PROTOCOL)

    def test_ping(self):
        self.assertEqual(self.client.ask("ping")["result"], {})

    def test_notification_is_silent(self):
        self.client.notify("notifications/cancelled", {"requestId": 1})
        self.client.notify("nothing/like/this")
        self.assertFalse(self.client.has_line(0.5))
        self.assertEqual(self.client.ask("ping")["result"], {})

    def test_parse_error(self):
        self.client.raw("{this is not json")
        answer = json.loads(self.client.line())
        self.assertIsNone(answer["id"])
        self.assertEqual(answer["error"]["code"], -32700)

    def test_unknown_method(self):
        answer = self.client.ask("prompts/list")
        self.assertEqual(answer["error"]["code"], -32601)

    def test_invalid_request(self):
        self.client.raw(json.dumps({"id": 99, "method": "ping"}))
        answer = json.loads(self.client.line())
        self.assertEqual(answer["error"]["code"], -32600)

    def test_unknown_tool(self):
        answer = self.client.ask("tools/call", {"name": "referee_strat", "arguments": {}})
        self.assertEqual(answer["error"]["code"], -32602)
        self.assertIn("referee_start", answer["error"]["data"]["suggestions"])

    def test_batch(self):
        self.client.raw(json.dumps([{"jsonrpc": "2.0", "id": 501, "method": "ping"},
                                    {"jsonrpc": "2.0", "method": "notifications/initialized"},
                                    {"jsonrpc": "2.0", "id": 502, "method": "ping"}]))
        answers = json.loads(self.client.line())
        self.assertEqual([a["id"] for a in answers], [501, 502])

    # --- the catalogue ----------------------------------------------------

    def test_catalogue_is_self_describing(self):
        tools = self.client.ask("tools/list")["result"]["tools"]
        names = [t["name"] for t in tools]
        for must in ("status", "contract", "manual", "packs", "cards", "check_deck", "list_decks", "read_deck",
                     "write_deck", "convert_deck", "autodeck", "lab", "lab_resume", "read_run", "lab_next",
                     "referee_start", "referee_join", "referee_host", "referee_act", "referee_autoplay", "referee_wait",
                     "referee_stop", "referee_resume"):
            self.assertIn(must, names)
        self.assertEqual(len(names), len(set(names)))
        by_name = {t["name"]: t for t in tools}
        self.assertIn("until", by_name["referee_act"]["inputSchema"]["properties"])
        for key in ("invitation", "table", "deck", "log", "keep", "view"):
            self.assertIn(key, by_name["referee_join"]["inputSchema"]["properties"], key)
        hosting = by_name["referee_host"]["inputSchema"]
        for key in ("table", "deck", "access", "name", "port", "address", "wait", "log", "keep", "view"):
            self.assertIn(key, hosting["properties"], key)
        self.assertEqual(hosting["required"], ["table", "deck"])
        self.assertEqual(hosting["properties"]["access"]["enum"], ["open", "invitation"])
        self.assertEqual(by_name["referee_join"]["inputSchema"]["required"], ["deck"])
        self.assertIn("keep", by_name["referee_start"]["inputSchema"]["properties"])
        self.assertIn("delta", by_name["referee_start"]["inputSchema"]["properties"]["view"]["description"])
        self.assertIn("referee_resume", by_name["referee_resume"]["description"] + by_name["referee_start"]["inputSchema"]["properties"]["keep"]["description"])
        for tool in tools:
            self.assertGreaterEqual(len(tool["description"]), 40, tool["name"])
            schema = tool["inputSchema"]
            self.assertEqual(schema["type"], "object", tool["name"])
            self.assertIs(schema["additionalProperties"], False, tool["name"])
            for key, spec in schema["properties"].items():
                self.assertTrue(spec.get("description"), "%s.%s has no description" % (tool["name"], key))
                self.assertIn("type", spec, "%s.%s has no type" % (tool["name"], key))
            for key in schema.get("required", []):
                self.assertIn(key, schema["properties"], "%s requires %s it does not describe" % (tool["name"], key))
            self.assertNotIn("handler", tool)

    def test_resources(self):
        rows = self.client.ask("resources/list")["result"]["resources"]
        uris = [r["uri"] for r in rows]
        self.assertIn("shandalar://contract", uris)
        self.assertIn("shandalar://manual/lab", uris)
        page = self.client.ask("resources/read", {"uri": "shandalar://contract"})["result"]["contents"][0]
        self.assertEqual(page["mimeType"], "text/markdown")
        self.assertIn("# The contract", page["text"])
        manual = self.client.ask("resources/read", {"uri": "shandalar://manual/lab"})["result"]["contents"][0]
        self.assertIn("FAKE HELP for lab", manual["text"])
        self.assertIn("error", self.client.ask("resources/read", {"uri": "shandalar://nothing"}))

    # --- the small tools ------------------------------------------------

    def test_play_guide_is_read_only_and_can_be_read_by_chapter(self):
        names = [tool["name"] for tool in self.client.ask("tools/list")["result"]["tools"]]
        self.assertIn("play_guide", names)
        before = self.calls()
        page = self.client.payload("play_guide")
        self.assertEqual(page["text"], self.guide)
        self.assertTrue(page["file"].endswith("agentic-playgude-mtg.md"))
        for chapter in range(1, 17):
            page = self.client.payload("play_guide", {"chapter": chapter})
            self.assertEqual(page["chapter"], chapter)
            self.assertEqual(page["text"], f"## {chapter}. Chapter {chapter}\n\nLesson {chapter}.\n")
        self.assertEqual(self.calls(), before, "reading guidance never invokes the engine")

    def test_play_guide_rejects_invalid_chapters(self):
        for chapter in (0, 17, -1, True, 1.5, "8", None):
            with self.subTest(chapter=chapter):
                result = self.client.call("play_guide", {"chapter": chapter})
                self.assertTrue(result["isError"])
                self.assertEqual(result["structuredContent"]["error"]["kind"], "option")

    def test_play_guide_resource_matches_tool(self):
        rows = self.client.ask("resources/list")["result"]["resources"]
        self.assertIn("shandalar://play-guide", [row["uri"] for row in rows])
        page = self.client.ask("resources/read", {"uri": "shandalar://play-guide"})["result"]["contents"][0]
        self.assertEqual(page["mimeType"], "text/markdown")
        self.assertEqual(page["text"], self.client.payload("play_guide")["text"])

    def test_missing_play_guide_is_a_clear_refusal(self):
        page = self.home / "agentic-playgude-mtg.md"
        page.rename(page.with_suffix(".saved"))
        try:
            result = self.client.call("play_guide")
            self.assertTrue(result["isError"])
            self.assertEqual(result["structuredContent"]["error"]["kind"], "path")
        finally:
            page.with_suffix(".saved").rename(page)

    def test_status_and_contract_and_manual(self):
        status = self.client.payload("status")
        self.assertEqual(status["version"], "9.9.9")
        self.assertEqual(status["root"], str(self.home.resolve()))
        self.assertEqual(status["workspace"], str(self.workspace.resolve()))
        self.assertIn("lab", status["tools"])
        self.assertIn("## The MCP server", self.client.payload("contract")["text"])
        self.assertIn("FAKE HELP for door", self.client.payload("manual", {"verb": "door"})["text"])
        self.assertIn("FAKE HELP for referee", self.client.payload("manual", {"verb": "referee"})["text"])
        refused = self.client.call("manual", {"verb": "labb"})
        self.assertTrue(refused["isError"])
        self.assertEqual(refused["structuredContent"]["error"]["suggestions"], ["lab"])

    def test_packs_is_quoted(self):
        result = self.client.call("packs")
        self.assertFalse(result["isError"])
        self.assertEqual(result["structuredContent"]["known"], ["pack-1"])
        self.assertEqual(json.loads(result["content"][0]["text"])["known"], ["pack-1"])

    def test_cards(self):
        rows = self.client.payload("cards", {"names": ["Lightning Bolt", "Lightnin Bolt"]})["cards"]
        self.assertTrue(rows[0]["known"])
        self.assertEqual(rows[1]["near"], ["Lightning Bolt"])
        # every pack the server finds is in play unless `packs` says otherwise (2026-10-04)
        self.assertEqual(self.calls()[-1], ["cards", "--packs", "all", "Lightning Bolt", "Lightnin Bolt"])

    def test_cards_know_every_pack_the_server_finds(self):
        # The 2026-10-04 play-through: a Pack 8 card answered `known: false`
        # unless `packs` was passed — the game's own setting had it off.
        imp = self.client.payload("cards", {"names": ["Teferi's Imp"]})
        self.assertTrue(imp["cards"][0]["known"])
        self.assertEqual(imp["packs"], "all")
        none = self.client.payload("cards", {"names": ["Teferi's Imp"], "packs": "none"})
        self.assertFalse(none["cards"][0]["known"])
        self.assertEqual(self.calls()[-1], ["cards", "--packs", "none", "Teferi's Imp"])
        self.assertTrue(self.client.payload("cards", {"names": ["Teferi's Imp"], "packs": "8"})["cards"][0]["known"])
        # a found pack that cannot be enabled: the game's own setting answers
        broken = self.home / "packs_broken"
        broken.write_text("x", encoding="utf-8")
        try:
            fallback = self.client.payload("cards", {"names": ["Teferi's Imp"]})
        finally:
            broken.unlink()
        self.assertFalse(fallback["cards"][0]["known"])
        self.assertEqual(self.calls()[-2:], [["cards", "--packs", "all", "Teferi's Imp"], ["cards", "Teferi's Imp"]])

    def test_refusal_keeps_the_envelope(self):
        result = self.client.call("check_deck", {"decks": ["missing.deck"]})
        self.assertTrue(result["isError"])
        error = result["structuredContent"]["error"]
        self.assertEqual(error["tool"], "lab_query")
        self.assertEqual(error["kind"], "deck")
        self.assertEqual(error["exit"], 2)
        self.assertEqual(error["path"], "missing.deck")

    def test_unknown_argument_is_refused_with_suggestions(self):
        result = self.client.call("check_deck", {"decks": ["x"], "pack": "all"})
        self.assertTrue(result["isError"])
        error = result["structuredContent"]["error"]
        self.assertEqual(error["kind"], "option")
        self.assertEqual(error["flag"], "pack")
        self.assertIn("packs", error["suggestions"])
        self.assertIn("decks", error["arguments"])
        missing = self.client.call("cards", {})
        self.assertEqual(missing["structuredContent"]["error"]["flag"], "names")

    # --- the decks --------------------------------------------------------

    def test_write_read_list_decks(self):
        written = self.client.payload("write_deck", {"file": "mine.deck", "name": "Mine",
                                                     "cards": ["4 Lightning Bolt", {"count": 20, "name": "Mountain"}],
                                                     "sideboard": "3 Red Elemental Blast"})
        path = self.workspace / "mine.deck"
        self.assertTrue(path.is_file())
        self.assertEqual(path.read_text(encoding="utf-8"),
                         "name: Mine\n4 Lightning Bolt\n20 Mountain\nSB: 3 Red Elemental Blast\n")
        self.assertEqual(written["cards"], 24)
        self.assertTrue(written["playable"])
        self.assertEqual(written["check"]["decks"][0]["cards"], 24)
        again = self.client.call("write_deck", {"file": "mine.deck", "cards": ["1 Island"]})
        self.assertTrue(again["isError"])
        self.assertEqual(again["structuredContent"]["error"]["kind"], "out")
        bogus = self.client.payload("write_deck", {"file": "mine.deck", "name": "Mine", "cards": ["4 Bogus Card"], "force": True})
        self.assertFalse(bogus["playable"])
        self.assertEqual(bogus["check"]["decks"][0]["unknown"], ["Bogus Card"])
        bad = self.client.call("write_deck", {"file": "bad.deck", "cards": ["Lightning Bolt"]})
        self.assertTrue(bad["isError"])
        self.assertEqual(bad["structuredContent"]["error"]["flag"], "cards")
        unchecked = self.client.payload("write_deck", {"file": "sub/raw.deck", "cards": "2 Island\n1 Plains", "check": False})
        self.assertNotIn("check", unchecked)
        self.assertEqual(unchecked["cards"], 3)
        read = self.client.payload("read_deck", {"deck": "tournament/burn.deck"})
        self.assertEqual(read["name"], "Burn")
        self.assertEqual(read["cards"], 24)
        self.assertEqual(read["sideboard"], [{"count": 3, "name": "Red Elemental Blast"}])
        self.assertEqual(read["main"][0], {"count": 4, "name": "Lightning Bolt"})
        dck = self.client.payload("read_deck", {"deck": "decks/old.dck"})
        self.assertEqual(dck["format"], "dck")
        self.assertNotIn("main", dck)
        lost = self.client.call("read_deck", {"deck": "burn.dek"})
        self.assertTrue(lost["isError"])
        self.assertIn("decks/tournament/burn.deck", lost["structuredContent"]["error"]["suggestions"])
        listed = self.client.payload("list_decks")
        files = {row["file"]: row for row in listed["decks"]}
        self.assertEqual(files["decks/tournament/burn.deck"]["group"], "tournament")
        self.assertEqual(files["decks/tournament/burn.deck"]["cards"], 24)
        self.assertEqual(files["decks/old.dck"]["format"], "dck")
        self.assertEqual(files["ws/mine.deck"]["name"], "Mine")
        one = self.client.payload("list_decks", {"folder": "decks/tournament"})
        self.assertEqual([r["file"] for r in one["decks"]], ["decks/tournament/burn.deck"])

    def test_paths_outside_are_refused(self):
        for tool, args in (("write_deck", {"file": "/etc/evil.deck", "cards": ["1 Island"]}),
                           ("write_deck", {"file": "../../evil.deck", "cards": ["1 Island"]}),
                           ("lab", {"deck_a": "a", "deck_b": "b", "out": "/tmp/somewhere"}),
                           ("autodeck", {"out": "../out"}),
                           ("read_run", {"out": "/"}),
                           ("referee_start", {"deck_a": "a", "deck_b": "b", "log": "/tmp/x.log"}),
                           ("convert_deck", {"input": "a.dck", "output": "/tmp/a.deck"})):
            result = self.client.call(tool, args)
            self.assertTrue(result["isError"], (tool, args))
            self.assertEqual(result["structuredContent"]["error"]["kind"], "path", (tool, args))
        self.assertFalse((Path("/etc") / "evil.deck").exists())

    def test_convert_deck(self):
        (self.home / "old.dck").write_text("bytes", encoding="utf-8")
        out = self.client.payload("convert_deck", {"input": "old.dck", "output": "ws/old.deck"})
        self.assertEqual(out["output"], "ws/old.deck")
        self.assertTrue((self.workspace / "old.deck").is_file())
        self.assertIn("converted", out["report"])

    def test_a_deck_the_server_wrote_is_named_by_its_file_name(self):
        """`write_deck` puts a deck in the workspace; the door never looks
        there, so every tool that names a deck hands a workspace file (or
        folder) over as its absolute path — and leaves the door's own
        spellings alone."""
        self.client.payload("write_deck", {"file": "own.deck", "name": "Own", "cards": ["4 Lightning Bolt", "20 Mountain"]})
        own = str((self.workspace / "own.deck").resolve())
        (self.workspace / "pool").mkdir(exist_ok=True)
        pool = str((self.workspace / "pool").resolve())
        checked = self.client.payload("check_deck", {"decks": ["own.deck", "decks/tournament/burn.deck"]})
        self.assertEqual([d["cards"] for d in checked["decks"]], [24, 24])
        self.assertEqual(self.calls()[-1][:3], ["check", own, "decks/tournament/burn.deck"])
        plan = self.client.payload("lab", {"deck_a": "own.deck", "deck_b": "random", "deck_pool": "pool",
                                           "gauntlet": "own.deck, decks/tournament", "field": "pool,tournament/burn.deck",
                                           "control_deck_a": "own.deck", "dry_run": True})
        argv = plan["argv"]
        self.assertEqual(argv[argv.index("--deck-a") + 1], own)
        self.assertEqual(argv[argv.index("--deck-b") + 1], "random")
        self.assertEqual(argv[argv.index("--deck-pool") + 1], pool)
        self.assertEqual(argv[argv.index("--gauntlet") + 1], own + ",decks/tournament")
        self.assertEqual(argv[argv.index("--field") + 1], pool + ",tournament/burn.deck")
        self.assertEqual(argv[argv.index("--control-deck-a") + 1], own)
        kept = self.client.payload("autodeck", {"out": "ws/around", "keep": "own.deck", "dry_run": True})
        self.assertEqual(kept["argv"][kept["argv"].index("--keep") + 1], own)
        opened = self.client.payload("referee_start", {"deck_a": "own.deck", "deck_b": "tournament/burn.deck"})
        self.assertEqual(self.calls()[-1][:5], ["referee", "--deck-a", own, "--deck-b", "tournament/burn.deck"])
        self.client.payload("referee_stop", {"game": opened["game"]})
        joined = self.client.payload("referee_join", {"invitation": "sglan1:x", "deck": "own.deck"})
        self.assertEqual(self.calls()[-1][:5], ["referee", "--join", "sglan1:x", "--deck", own])
        self.client.payload("referee_stop", {"game": joined["game"]})
        typo = self.client.call("lab", {"deck_a": "missing.deck", "deck_b": "own.deck"})
        self.assertTrue(typo["isError"], "a name nowhere is still the door's refusal")
        self.assertEqual(typo["structuredContent"]["error"]["path"], "missing.deck")

    # --- the Lab and the AutoDeck -----------------------------------------

    def test_lab_builds_the_line(self):
        plan = self.client.payload("lab", {"deck_a": "a.deck", "deck_b": "b.deck", "games": 20, "seed": 3,
                                           "profile_b": "wizard", "dry_run": True, "extra_args": ["--rule", "x=1"]})
        argv = plan["argv"]
        self.assertEqual(argv[:8], ["--deck-a", "a.deck", "--deck-b", "b.deck", "--games", "20", "--seed", "3"])
        self.assertIn("--no-elo", argv)
        self.assertIn("--dry-run", argv)
        self.assertEqual(argv[-1], "--quiet")
        self.assertEqual(argv[argv.index("--rule") + 1], "x=1")
        self.assertTrue(plan["plan"]["dry_run"])
        rated = self.client.payload("lab", {"deck_a": "a.deck", "gauntlet": "decks/tournament", "rated": True, "dry_run": True})
        self.assertNotIn("--no-elo", rated["argv"])
        self.assertIn("--gauntlet", rated["argv"])
        raw = self.client.payload("lab", {"argv": ["--matrix", "decks/tournament", "--games", "5", "--dry-run"]})
        # A line that names no folder is given one under the workspace
        # (2026-10-03), the folder the answer then reads `run.json` from.
        self.assertEqual(raw["argv"][:6], ["--matrix", "decks/tournament", "--games", "5", "--dry-run", "--no-elo"])
        self.assertEqual(raw["argv"][-3], "--out")
        self.assertEqual(Path(raw["argv"][-2]).parent, (self.workspace / "runs").resolve())
        self.assertTrue(Path(raw["argv"][-2]).name.startswith("lab-"))
        self.assertEqual(raw["argv"][-1], "--quiet")

    def test_lab_run_and_results(self):
        out = self.client.payload("lab", {"deck_a": "a.deck", "deck_b": "b.deck", "games": 20, "out": "ws/run1", "limit": 2})
        self.assertEqual(out["exit"], 0)
        self.assertEqual(out["report"], "REPORT\n")
        self.assertEqual(out["run"]["tool"], "lab")
        self.assertEqual(out["next"]["argv"][5], "9")
        self.assertEqual(len(out["results"]["matchups"]), 2)
        self.assertEqual(out["results"]["matchups_total"], 3)
        self.assertTrue(out["results"]["truncated"])
        self.assertIn("ws/run1/results.json", out["files"])
        read = self.client.payload("read_run", {"out": "ws/run1"})
        self.assertEqual(len(read["results"]["matchups"]), 3)
        self.assertEqual(read["report"], "REPORT\n")
        nxt = self.client.payload("lab_next", {"out": "ws/run1"})
        self.assertEqual(nxt["why"], "one matchup straddles even")
        self.assertEqual(nxt["from"], "ws/run1")
        self.assertEqual(nxt["argv"][:6], ["--deck-a", "a.deck", "--deck-b", "b.deck", "--games", "9"])
        self.assertIsNone(nxt["next"])
        done = self.client.payload("lab_next", {"out": "ws/run1"})
        self.assertIsNone(done["next"])
        self.assertIn("why", done)
        resumed = self.client.payload("lab_resume", {"out": "ws/run1"})
        self.assertEqual(resumed["argv"][:2], ["--resume", str((self.workspace / "run1").resolve())])
        swept = self.client.payload("lab", {"sweep": "knob=1,2", "deck_a": "a.deck", "deck_b": "b.deck",
                                            "control_deck_a": "a.deck", "control_deck_b": "b.deck", "out": "ws/run2"})
        self.assertEqual(swept["exit"], 4)
        self.assertIn("control pair", swept["warning"])
        refused = self.client.call("lab", {"deck_a": "missing.deck", "deck_b": "b.deck", "out": "ws/run3"})
        self.assertTrue(refused["isError"])
        self.assertEqual(refused["structuredContent"]["error"]["tool"], "deck_lab")
        empty = self.client.call("read_run", {"out": "ws"})
        self.assertTrue(empty["isError"])

    def test_a_lab_run_without_out_goes_to_the_workspace_and_is_read(self):
        # 2026-10-03: the folder was looked for on stderr while the Lab
        # names it on stdout, so the answer had no run, results or next.
        out = self.client.payload("lab", {"deck_a": "a.deck", "deck_b": "b.deck", "games": 20})
        folder = Path(out["argv"][out["argv"].index("--out") + 1])
        self.assertEqual(folder.parent, (self.workspace / "runs").resolve())
        self.assertEqual(out["run"]["tool"], "lab")
        self.assertIn("matchups", out["results"])
        self.assertIn("next", out)
        self.assertTrue((folder / "run.json").is_file())

    def test_a_lab_run_reports_progress_to_a_client_that_asks(self):
        # MCP progress (2026-10-03): with `_meta.progressToken` the server
        # runs the Lab with `--progress json` and turns each heartbeat into
        # `notifications/progress`, before the answer, always increasing.
        ident = self.client.next_id
        self.client.next_id += 1
        self.client.raw(json.dumps({"jsonrpc": "2.0", "id": ident, "method": "tools/call", "params": {
            "name": "lab", "_meta": {"progressToken": "lab-1"},
            "arguments": {"deck_a": "a.deck", "deck_b": "b.deck", "out": "ws/progress"}}}))
        notes = []
        while True:
            message = json.loads(self.client.line(30))
            if message.get("method") == "notifications/progress":
                notes.append(message["params"])
                continue
            self.assertEqual(message.get("id"), ident, message)
            answer = message
            break
        self.assertFalse(answer["result"]["isError"], answer)
        self.assertIn("--progress", answer["result"]["structuredContent"]["argv"])
        self.assertEqual([n["progress"] for n in notes], [1, 2, 3])
        self.assertTrue(all(n["progressToken"] == "lab-1" and n["total"] == 3 for n in notes))
        self.assertEqual(notes[-1]["message"], "3 of 3 games")
        # Without a token nothing is reported and nothing extra is asked.
        plain = self.client.payload("lab", {"deck_a": "a.deck", "deck_b": "b.deck", "out": "ws/progress2"})
        self.assertNotIn("--progress", plain["argv"])
        self.assertFalse(self.client.has_line(0.3))

    def test_lab_resume_is_a_line_the_lab_takes(self):
        # 2026-10-03: the server sent `--resume OUT --quiet`, and the real
        # Lab refused anything beside `--resume` — every lab_resume failed.
        first = self.client.payload("lab", {"deck_a": "a.deck", "deck_b": "b.deck", "out": "ws/resumable"})
        self.assertEqual(first["exit"], 0)
        resumed = self.client.call("lab_resume", {"out": "ws/resumable"})
        self.assertFalse(resumed["isError"], resumed)

    def test_a_cancelled_call_is_not_answered_and_ping_is_not_held(self):
        pid_file = self.home / "sleeping.pid"
        pid_file.unlink(missing_ok=True)
        ident = self.client.next_id
        self.client.next_id += 1
        self.client.raw(json.dumps({"jsonrpc": "2.0", "id": ident, "method": "tools/call", "params": {
            "name": "lab", "arguments": {"deck_a": "a.deck", "deck_b": "b.deck", "out": "ws/slow",
                                         "extra_args": ["--sleep", "60"]}}}))
        deadline = time.time() + 20
        while not pid_file.is_file() and time.time() < deadline:
            time.sleep(0.05)
        self.assertTrue(pid_file.is_file(), "the slow door never started")
        child = int(pid_file.read_text())
        started = time.time()
        self.assertEqual(self.client.ask("ping", timeout=5)["result"], {})
        self.assertLess(time.time() - started, 5, "a ping waited behind the Lab run")
        self.client.notify("notifications/cancelled", {"requestId": ident, "reason": "test"})
        gone = False
        deadline = time.time() + 15
        while time.time() < deadline:
            try:
                os.kill(child, 0)
            except ProcessLookupError:
                gone = True
                break
            time.sleep(0.1)
        self.assertTrue(gone, "the cancelled call's door child is still running")
        # Nothing is said for the cancelled call; the next request is
        # answered as usual.
        answer = self.client.ask("ping", timeout=10)
        self.assertEqual(answer["result"], {})
        self.assertFalse(self.client.has_line(0.5))

    def test_autodeck(self):
        plan = self.client.payload("autodeck", {"out": "ws/field", "count": 3, "colors": "WU,BR", "max_colors": 2,
                                                "dry_run": True})
        self.assertEqual(plan["argv"][:2], ["--out", str((self.workspace / "field").resolve())])
        self.assertIn("--max-colors", plan["argv"])
        self.assertIn("--dry-run", plan["argv"])
        built = self.client.payload("autodeck", {"out": "ws/field", "count": 2, "seed": 1})
        self.assertEqual(built["count"], 2)
        self.assertEqual(built["decks"], ["ws/field/d1.deck", "ws/field/d2.deck"])
        self.assertEqual(built["run"]["tool"], "autodeck")
        self.assertIn("next", built)

    # --- the game -----------------------------------------------------------

    def test_game_lifecycle(self):
        opened = self.client.payload("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck", "seat_b": "wizard", "seed": 7})
        game = opened["game"]
        self.assertEqual(opened["hello"]["seed"], 7)
        self.assertEqual(opened["hello"]["seats"][1]["player"], "wizard")
        decision = opened["decision"]
        self.assertEqual(decision["mode"], "opening")
        self.assertIn("keep", decision["options"])
        self.assertNotIn("view", decision)
        brief = decision["brief"]
        self.assertEqual(brief["players"][1]["battlefield"][0]["pt"], "2/2")
        self.assertEqual(brief["hand"][1]["cost"], "{R}")
        self.assertTrue(brief["hand"][1]["castable"])
        self.assertTrue(brief["hand"][0]["land"])
        self.assertEqual(brief["journal"], ["Toss: seat 0 plays first"])
        self.assertEqual(opened["decisions"], 1)
        # the wire's own line on request
        full = self.client.payload("referee_wait", {"game": game, "view": "full"})
        self.assertIn("view", full["decision"])
        self.assertEqual(full["decision"]["n"], 0)
        # a wrong answer: refused, the same decision back
        wrong = self.client.payload("referee_act", {"game": game, "action": {"op": "dance"}, "view": "options"})
        self.assertEqual(wrong["refused"][0]["reason"], "unknown op 'dance'")
        self.assertEqual(wrong["decision"]["n"], 0)
        self.assertNotIn("brief", wrong["decision"])
        self.assertEqual(wrong["refusals"], 1)
        self.assertEqual(wrong["action"], {"op": "dance", "seat": 0})
        # the pilot, after a refusal on this decision, gives the quiet answer; then plays the land
        kept = self.client.payload("referee_act", {"game": game, "action": "default"})
        self.assertEqual(kept["action"], {"op": "keep", "seat": 0})
        self.assertEqual(kept["decision"]["n"], 1)
        land = self.client.payload("referee_act", {"game": game, "action": "default"})
        self.assertEqual(land["action"], {"op": "play", "card": "c1", "seat": 0})
        spell = self.client.payload("referee_act", {"game": game, "action": "default"})
        self.assertEqual(spell["action"]["op"], "prepare")
        self.assertEqual(spell["action"]["card"], "c2")
        # a typed answer
        passed = self.client.payload("referee_act", {"game": game, "action": {"op": "pass"}})
        self.assertEqual(passed["decision"]["n"], 4)
        status = self.client.payload("status")
        row = [g for g in status["games"] if g["game"] == game][0]
        self.assertTrue(row["running"])
        self.assertEqual(row["pending"]["n"], 4)
        ended = self.client.payload("referee_act", {"game": game, "action": {"op": "concede"}})
        self.assertEqual(ended["result"]["reason"], "concede")
        self.assertEqual(ended["result"]["winner"], 1)
        self.assertNotIn("decision", ended)
        after = self.client.payload("referee_act", {"game": game, "action": "default"})
        self.assertFalse(after["running"])
        self.assertEqual(after["result"]["reason"], "concede")
        stopped = self.client.payload("referee_stop", {"game": game})
        self.assertEqual(stopped["result"]["winner"], 1)
        self.assertTrue((self.workspace / "games" / (game + ".stderr")).is_file())

    def test_autoplay_and_stop(self):
        opened = self.client.payload("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck"})
        game = opened["game"]
        two = self.client.payload("referee_autoplay", {"game": game, "decisions": 2})
        self.assertEqual(two["played"], 2)
        self.assertEqual(two["decision"]["n"], 2)
        rest = self.client.payload("referee_autoplay", {"game": game})
        self.assertEqual(rest["result"]["reason"], "concluded")
        self.assertEqual(rest["result"]["decisions"], 6)
        other = self.client.payload("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck"})
        stopped = self.client.payload("referee_stop", {"game": other["game"]})
        self.assertEqual(stopped["result"]["reason"], "eof")
        self.assertFalse(stopped["running"])

    def test_game_refusals(self):
        none = self.client.call("referee_act", {"game": "g999", "action": "default"})
        self.assertTrue(none["isError"])
        self.assertEqual(none["structuredContent"]["error"]["kind"], "game")
        missing = self.client.call("referee_start", {"deck_a": "missing.deck", "deck_b": "b.deck"})
        self.assertTrue(missing["isError"])
        self.assertEqual(missing["structuredContent"]["error"]["tool"], "referee")
        seat = self.client.call("referee_start", {"deck_a": "a", "deck_b": "b", "seat_b": "wizzard"})
        self.assertEqual(seat["structuredContent"]["error"]["suggestions"], ["wizard"])
        view = self.client.call("referee_start", {"deck_a": "a", "deck_b": "b", "view": "long"})
        self.assertEqual(view["structuredContent"]["error"]["flag"], "view")

    def test_join_waits(self):
        opened = self.client.payload("referee_join", {"invitation": "sglan1:abc", "deck": "a.deck", "wait": 77, "timeout": 0.5})
        self.assertTrue(opened["pending"])
        self.assertIsNone(opened["hello"])
        game = opened["game"]
        first = self.client.payload("referee_wait", {"game": game, "timeout": 15})
        self.assertEqual(first["decision"]["n"], 0)
        self.assertEqual(first["hello"]["table"], {"host": "Someone"})
        # a joined table is kept by default: the referee listens, the
        # record is on disk, and the stop is a concession
        record = json.loads((self.workspace / "games" / (game + ".json")).read_text(encoding="utf-8"))
        self.assertEqual(record["game"], game)
        keep = str(self.workspace / "games" / (game + ".keep.json"))
        self.assertIn(["referee", "--join", "sglan1:abc", "--deck", "a.deck", "--wait", "77",
                       "--listen", keep, "--idle", str(mcp.KEEP_IDLE)], self.calls())
        self.assertTrue(json.loads(Path(keep).read_text(encoding="utf-8"))["port"] > 0)
        stopped = self.client.payload("referee_stop", {"game": game})
        self.assertEqual(stopped["result"]["reason"], "concede")
        self.assertTrue(stopped["kept"])
        self.assertFalse((self.workspace / "games" / (game + ".json")).is_file())
        transcript = (self.workspace / "games" / (game + ".lines")).read_text(encoding="utf-8")
        self.assertIn('"type": "result"', transcript)

    def test_join_by_table_name_with_a_log(self):
        opened = self.client.payload("referee_join", {"table": "Kitchen", "deck": "a.deck", "log": "kitchen.log",
                                                      "keep": False, "timeout": 15})
        game = opened["game"]
        self.assertEqual(opened["hello"]["table"], {"host": "Someone", "name": "Kitchen"})
        self.assertEqual(opened["decision"]["n"], 0)
        log = self.home / "kitchen.log"
        self.assertEqual(opened["hello"]["log"], str(log))
        self.assertIn(["referee", "--table", "Kitchen", "--deck", "a.deck", "--log", str(log)], self.calls())
        stopped = self.client.payload("referee_stop", {"game": game})
        self.assertEqual(stopped["result"]["reason"], "eof")
        self.assertNotIn("kept", stopped)
        self.assertTrue(log.is_file())
        both = self.client.call("referee_join", {"invitation": "sglan1:abc", "table": "Kitchen", "deck": "a.deck"})
        self.assertTrue(both["isError"])
        self.assertEqual(both["structuredContent"]["error"]["flag"], "table")
        neither = self.client.call("referee_join", {"deck": "a.deck"})
        self.assertEqual(neither["structuredContent"]["error"]["flag"], "invitation")

    def test_host_announces_the_table_then_waits(self):
        # the table line is the answer; hello comes when the guest sits down
        opened = self.client.payload("referee_host", {"table": "Kitchen", "deck": "a.deck", "access": "invitation",
                                                      "name": "Ref", "port": 0, "wait": 77, "timeout": 15})
        game = opened["game"]
        self.assertTrue(opened["pending"])
        self.assertIsNone(opened["hello"])
        self.assertEqual(opened["table"], {"type": "table", "id": "r1", "name": "Kitchen", "access": "invitation",
                                           "host": "Ref", "address": "127.0.0.1", "port": 17897,
                                           "invitation": "sglan1:fake", "discovery": True})
        self.assertIn("pastes its `invitation`", opened["note"])
        keep = str(self.workspace / "games" / (game + ".keep.json"))
        self.assertIn(["referee", "--host", "Kitchen", "--deck", "a.deck", "--access", "invitation", "--name", "Ref",
                       "--port", "0", "--wait", "77", "--listen", keep, "--idle", str(mcp.KEEP_IDLE)], self.calls())
        row = [g for g in self.client.payload("status")["games"] if g["game"] == game][0]
        self.assertEqual(row["hosted"]["invitation"], "sglan1:fake")
        self.assertNotIn("table", row)
        # a wait that runs out keeps naming the table; the one that lasts gets the duel
        held = self.client.payload("referee_wait", {"game": game, "timeout": 0.2})
        self.assertTrue(held["pending"])
        self.assertEqual(held["table"]["name"], "Kitchen")
        self.assertIn("chair is held", held["note"])
        first = self.client.payload("referee_wait", {"game": game, "timeout": 15})
        self.assertEqual(first["decision"]["n"], 0)
        self.assertEqual(first["hello"]["table"], {"id": "r1", "name": "Kitchen", "seat": 0, "hosted": True})
        self.assertNotIn("table", first)
        row = [g for g in self.client.payload("status")["games"] if g["game"] == game][0]
        self.assertEqual(row["table"]["hosted"], True)
        self.assertEqual(row["hosted"]["name"], "Kitchen")
        stopped = self.client.payload("referee_stop", {"game": game})
        self.assertEqual(stopped["result"]["reason"], "concede")
        self.assertTrue(stopped["kept"])
        # an open table by default, not kept on request, and the access rule is checked first
        opened = self.client.payload("referee_host", {"table": "Porch", "deck": "a.deck", "keep": False, "log": "porch.log"})
        self.assertEqual(opened["table"]["access"], "open")
        self.assertIn("listed in every Game Browser", opened["note"])
        self.assertIn(["referee", "--host", "Porch", "--deck", "a.deck", "--log", str(self.home / "porch.log")], self.calls())
        self.assertNotIn("kept", self.client.payload("referee_stop", {"game": opened["game"]}))
        bad = self.client.call("referee_host", {"table": "Porch", "deck": "a.deck", "access": "secret"})
        self.assertTrue(bad["isError"])
        self.assertEqual(bad["structuredContent"]["error"]["flag"], "access")
        self.assertEqual(self.calls().count(["referee", "--host", "Porch", "--deck", "a.deck", "--access", "secret"]), 0)

    def test_pass_until_stops_where_a_player_acts(self):
        opened = self.client.payload("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck", "seed": 31})
        game = opened["game"]
        self.assertEqual(opened["decision"]["mode"], "opening")
        # a bad `until` is refused before the answer is sent
        bad = self.client.call("referee_act", {"game": game, "action": "default", "until": "ende"})
        self.assertEqual(bad["structuredContent"]["error"]["flag"], "until")
        self.assertEqual(bad["structuredContent"]["error"]["suggestions"], ["end"])
        # `play`: the first main phase with something to do (a land in hand)
        main = self.client.payload("referee_act", {"game": game, "action": "default", "until": "play"})
        self.assertEqual(main["action"], {"op": "order", "play": True, "seat": 0})
        self.assertEqual(main["stop"], "your main phase, with something to play")
        self.assertEqual((main["passed"], main["until"], main["decision"]["n"]), (0, "play", 1))
        # a refused answer stops the loop with the same decision
        wrong = self.client.payload("referee_act", {"game": game, "action": {"op": "dance"}, "until": "end"})
        self.assertEqual(wrong["stop"], "an answer was refused")
        self.assertEqual(wrong["decision"]["n"], 1)
        self.assertEqual(wrong["passed"], 0)
        # `end`: own declare-blockers with nothing to respond with is passed; the
        # end step stops, and the journal of the passed decision is in front
        end = self.client.payload("referee_act", {"game": game, "action": {"op": "play", "card": "c1"}, "until": "end"})
        self.assertEqual(end["stop"], "the end step")
        self.assertEqual((end["passed"], end["decision"]["n"], end["decision"]["step"]), (1, 3, "END"))
        self.assertEqual(end["decision"]["brief"]["journal"], ["n2: DECLARE_BLOCKERS", "n3: END"])
        self.assertEqual(end["decisions"], 4)
        # `turn`: the opponent's upkeep is passed; their spell on the stack stops
        stack = self.client.payload("referee_act", {"game": game, "action": {"op": "pass"}, "until": "turn"})
        self.assertEqual(stack["stop"], "the opponent's Grizzly Bears is on the stack and you can respond")
        self.assertEqual((stack["passed"], stack["decision"]["n"]), (1, 5))
        self.assertEqual(stack["decision"]["brief"]["journal"], ["n4: UPKEEP", "n5: MAIN1"])
        # the beginning of their combat is passed; declared attackers stop
        attackers = self.client.payload("referee_act", {"game": game, "action": {"op": "pass"}, "until": "turn"})
        self.assertEqual(attackers["stop"], "their declare attackers: you can respond")
        self.assertEqual((attackers["passed"], attackers["decision"]["n"]), (1, 7))
        # a block is never passed
        block = self.client.payload("referee_act", {"game": game, "action": {"op": "pass"}, "until": "turn"})
        self.assertEqual(block["stop"], "decision: block")
        self.assertEqual((block["passed"], block["decision"]["n"]), (0, 8))
        # their end step with an instant in hand stops
        their_end = self.client.payload("referee_act", {"game": game, "action": {"op": "block", "pairs": []}, "until": "turn"})
        self.assertEqual(their_end["stop"], "their end: you can respond")
        self.assertEqual(their_end["decision"]["n"], 9)
        # the own turn, then the own main phase
        turn = self.client.payload("referee_act", {"game": game, "action": {"op": "pass"}, "until": "turn"})
        self.assertEqual((turn["stop"], turn["decision"]["n"], turn["decision"]["turn"]), ("your turn", 10, 3))
        main2 = self.client.payload("referee_act", {"game": game, "action": {"op": "pass"}, "until": "main"})
        self.assertEqual((main2["stop"], main2["decision"]["step"]), ("your main phase", "MAIN2"))
        done = self.client.payload("referee_act", {"game": game, "action": {"op": "pass"}, "until": "turn"})
        self.assertEqual(done["result"]["reason"], "concluded")
        self.assertNotIn("stop", done)
        self.assertEqual(done["passed"], 0)

    def test_the_delta_view_shows_what_moved(self):
        opened = self.client.payload("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck", "seed": 31, "view": "delta"})
        game = opened["game"]
        first = opened["decision"]["delta"]
        self.assertTrue(first["baseline"])
        self.assertEqual(first["players"][0]["life"], 20)
        self.assertNotIn("brief", opened["decision"])
        # nothing moved between the opening and the first main phase
        same = self.client.payload("referee_act", {"game": game, "action": "default"})["decision"]["delta"]
        self.assertNotIn("baseline", same)
        self.assertNotIn("players", same)
        self.assertEqual(same["castable"], ["Lightning Bolt"])
        self.assertEqual(same["journal"], ["n1: MAIN1"])
        # the land left the hand for the board
        played = self.client.payload("referee_act", {"game": game, "action": {"op": "play", "card": "c1"}, "until": "end"})["decision"]["delta"]
        self.assertEqual(played["hand_gone"], ["Mountain (c1)"])
        self.assertEqual(played["players"], [{"seat": 0, "battlefield_added": [{"id": "c1", "name": "Mountain", "land": True}]}])
        self.assertEqual(played["journal"], ["n2: DECLARE_BLOCKERS", "n3: END"])
        # the opponent's spell shows on the stack
        stack = self.client.payload("referee_act", {"game": game, "action": {"op": "pass"}, "until": "turn"})["decision"]["delta"]
        self.assertEqual(stack["stack"][0]["name"], "Grizzly Bears")
        self.assertNotIn("players", stack)
        # their attacker changed state; the block decision itself carries the same board
        attackers = self.client.payload("referee_act", {"game": game, "action": {"op": "pass"}, "until": "turn"})["decision"]["delta"]
        self.assertEqual(attackers["players"], [{"seat": 1, "battlefield_changed": [{"id": "c9", "name": "Grizzly Bears", "pt": "2/2", "attacking": True}]}])
        block = self.client.payload("referee_act", {"game": game, "action": {"op": "pass"}, "until": "turn"})
        self.assertEqual(block["decision"]["mode"], "block")
        self.assertNotIn("players", block["decision"]["delta"])
        # the life that went, and the attacker that is one no more
        hit = self.client.payload("referee_act", {"game": game, "action": {"op": "block", "pairs": []}, "until": "turn"})["decision"]["delta"]
        self.assertEqual(hit["players"][0], {"seat": 0, "life": 18, "life_was": 20})
        self.assertEqual(hit["players"][1]["battlefield_changed"], [{"id": "c9", "name": "Grizzly Bears", "pt": "2/2"}])
        # the views can be switched on the way; `full` carries the wire's line
        full = self.client.payload("referee_act", {"game": game, "action": {"op": "pass"}, "until": "turn", "view": "full"})
        self.assertIn("view", full["decision"])
        self.assertNotIn("delta", full["decision"])
        self.client.payload("referee_stop", {"game": game})

    # --- 0.50.13: the agent interface the 2026-10-04 play-through asked for --

    def test_the_smart_pass_stops_only_where_you_hold_something(self):
        opened = self.client.payload("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck", "seed": 33})
        game = opened["game"]
        main = self.client.payload("referee_act", {"game": game, "action": "default", "until": "mine"})
        self.assertEqual((main["stop"], main["decision"]["n"], main["passed"]), ("your main phase, with something to play", 1, 0))
        # your empty second main and end step, their upkeep, their spell while you
        # hold only a sorcery: passed; their attack while you hold a castable instant: stopped
        attack = self.client.payload("referee_act", {"game": game, "action": {"op": "pass"}, "until": "mine"})
        self.assertEqual(attack["stop"], "their declare attackers; you hold Lightning Bolt (castable)")
        self.assertEqual((attack["decision"]["n"], attack["passed"]), (6, 4))
        # the whole journal of what was passed, in front of the decision's own
        self.assertEqual(attack["decision"]["brief"]["journal"],
                         ["n2: MAIN2", "n3: END", "n4: UPKEEP", "n5: MAIN1", "n6: DECLARE_ATTACKERS"])
        block = self.client.payload("referee_act", {"game": game, "action": {"op": "pass"}, "until": "mine"})
        self.assertEqual((block["stop"], block["passed"]), ("decision: block", 0))
        # their end step while the once-a-turn ability is spent (not listed): passed
        turn = self.client.payload("referee_act", {"game": game, "action": {"op": "block", "pairs": []}, "until": "mine"})
        self.assertEqual((turn["stop"], turn["decision"]["n"], turn["passed"]), ("your main phase, with something to play", 9, 1))
        self.client.payload("referee_stop", {"game": game})
        # mine-strict: nothing on their account but your own block
        opened = self.client.payload("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck", "seed": 33})
        game = opened["game"]
        self.client.payload("referee_act", {"game": game, "action": "default", "until": "mine-strict"})
        strict = self.client.payload("referee_act", {"game": game, "action": {"op": "pass"}, "until": "mine-strict"})
        self.assertEqual((strict["stop"], strict["decision"]["n"], strict["passed"]), ("decision: block", 7, 5))
        self.assertEqual(len(strict["decision"]["brief"]["journal"]), 6)
        self.client.payload("referee_stop", {"game": game})

    def test_autoplay_keeps_every_journal_line(self):
        # 2026-10-04: the decisions the pilot answered between lost their lines
        opened = self.client.payload("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck", "seed": 31})
        two = self.client.payload("referee_autoplay", {"game": opened["game"], "decisions": 2})
        self.assertEqual(two["decision"]["n"], 2)
        self.assertEqual(two["decision"]["brief"]["journal"], ["n1: MAIN1", "n2: DECLARE_BLOCKERS"])
        self.client.payload("referee_stop", {"game": opened["game"]})

    def test_the_compact_view_is_what_the_model_reads(self):
        opened = self.client.call("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck", "seed": 41, "view": "compact"})
        state = opened["structuredContent"]
        game = state["game"]
        decision = state["decision"]
        # structuredContent keeps the JSON (the brief, the options); content is the text
        self.assertIn("brief", decision)
        self.assertIn("options", decision)
        text = opened["content"][0]["text"]
        self.assertEqual(text, mcp.compact_answer(state, me=0) + "\n" + mcp.json_note("compact"))
        self.assertTrue(text.startswith("game %s | decisions 1 | refusals 0\nTURN 3 MAIN1 — your turn" % game), text)
        for line in ("  Holy Strength c14 [on Knight of Valor c4]",
                     "  Teferi's Imp c12 1/1 [PHASED OUT, returns at the opponent's next untap step]",
                     "  Lightning Bolt c2 {R} — CASTABLE | Lightning Bolt deals 3 damage to any target.",
                     "  play a land: Mountain c13 (referee_play_land)"):
            self.assertIn(line, text.splitlines())
        self.assertEqual(decision["compact"], text.split("\n", 1)[1].rsplit("\n", 1)[0])
        self.assertTrue(text.endswith("(The full JSON is in structuredContent — the decision in view `compact`; views: "
                                      "brief, delta, full, options, compact. `text: \"json\"` on referee_start puts the "
                                      "JSON here instead.)"), text[-300:])
        # referee_view reads it again in another view without changing the game's;
        # the content is the same compact table, the note names the view the JSON is in
        brief = self.client.call("referee_view", {"game": game, "view": "brief"})
        self.assertNotIn("compact", brief["structuredContent"]["decision"])
        self.assertIn("brief", brief["structuredContent"]["decision"])
        self.assertEqual(brief["content"][0]["text"].rsplit("\n", 1)[0], text.rsplit("\n", 1)[0])
        self.assertIn("the decision in view `brief`", brief["content"][0]["text"])
        full = self.client.call("referee_view", {"game": game, "view": "full"})
        self.assertIn("view", full["structuredContent"]["decision"])
        self.assertEqual(full["content"][0]["text"].rsplit("\n", 1)[0], text.rsplit("\n", 1)[0])
        self.assertEqual(self.client.call("referee_view", {"game": game})["content"][0]["text"], text)
        # a land by name, in one call; the answer is compact too
        land = self.client.call("referee_play_land", {"game": game, "card": "mountain"})
        self.assertEqual(land["structuredContent"]["action"], {"op": "play", "card": "c13", "seat": 0})
        self.assertIn('sent: {"card": "c13", "op": "play", "seat": 0}', land["content"][0]["text"])
        self.assertIn("  Agent plays Mountain", land["content"][0]["text"].splitlines())
        again = self.client.call("referee_play_land", {"game": game})
        self.assertTrue(again["isError"])
        self.assertIn("no land can be played now", again["structuredContent"]["error"]["message"])
        self.client.payload("referee_stop", {"game": game})

    def test_referee_cast_prepares_pays_and_submits_in_one_call(self):
        game = self.client.payload("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck", "seed": 41})["game"]
        bolt = self.client.payload("referee_cast", {"game": game, "card": "Lightning Bolt", "targets": ["c9"]})
        self.assertEqual(bolt["cast"]["result"], "cast")
        self.assertEqual(bolt["cast"]["targets"], [{"slot": 0, "token": "t3", "label": "Grizzly Bears — opponent's",
                                                   "target": "c9", "amount": 0}])
        self.assertEqual([s["op"] for s in bolt["sent"]], ["prepare", "autopay", "submit"])
        self.assertEqual(bolt["sent"][0], {"op": "prepare", "card": "c2", "kind": "spell", "index": 0, "x": 0, "mode": 0})
        self.assertEqual(bolt["sent"][2], {"op": "submit", "targets": [["t3", 0]]})
        self.assertEqual(bolt["decision"]["brief"]["stack"][0]["name"], "Lightning Bolt")
        self.assertEqual(bolt["decision"]["brief"]["journal"], ["Agent casts Lightning Bolt"])
        self.assertNotIn("refused", bolt)
        # with `until`, the pass lets it resolve and stops where there is something to do
        self.client.payload("referee_stop", {"game": game})
        game = self.client.payload("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck", "seed": 41})["game"]
        resolved = self.client.payload("referee_cast", {"game": game, "card": "c2", "targets": ["opponent"], "until": "mine"})
        self.assertEqual(resolved["stop"], "your main phase, with something to play")
        self.assertEqual(resolved["passed"], 1)
        self.assertEqual(resolved["decision"]["brief"]["players"][1]["life"], 17)
        self.assertEqual(resolved["decision"]["brief"]["journal"], ["Agent casts Lightning Bolt", "Lightning Bolt resolves"])
        self.client.payload("referee_stop", {"game": game})

    def test_referee_cast_never_leaves_a_half_announced_cast(self):
        game = self.client.payload("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck", "seed": 41})["game"]
        def refused(args):
            result = self.client.call("referee_cast", {"game": game, **args})
            self.assertTrue(result["isError"], result)
            return result["structuredContent"]["error"]
        # an ambiguous name: refused with the legal targets, nothing tapped, the announcement withdrawn
        error = refused({"card": "Lightning Bolt", "targets": ["Grizzly Bears"]})
        self.assertEqual(error["kind"], "target")
        self.assertIn("several targets are called 'Grizzly Bears'", error["message"])
        self.assertIn({"token": "t4", "label": "Grizzly Bears — opponent's", "card": "c10"}, error["legal"][0]["targets"])
        self.assertEqual([s["op"] for s in error["sent"]], ["prepare", "cancel"])
        self.assertTrue(error["cast"]["withdrawn"])
        self.assertNotIn("floating_mana", error["cast"])
        self.assertNotIn("announcement", error["decision"]["options"])
        self.assertIn("pass", error["decision"]["options"])
        # not a legal target at all
        error = refused({"card": "c2", "targets": ["c13"]})
        self.assertIn("is not a legal target for Lightning Bolt", error["message"])
        # the phantom once-a-turn ability: the payment tapped, the submission was refused —
        # withdrawn, and the mana that floats is said
        error = refused({"card": "Knight of Valor", "kind": "ability"})
        self.assertEqual((error["cast"]["stage"], error["cast"]["reason"]),
                         ("submit", "Knight of Valor: activate only once each turn"))
        self.assertEqual([s["op"] for s in error["sent"]], ["prepare", "autopay", "submit", "cancel"])
        self.assertEqual(error["cast"]["floating_mana"], "C1")
        self.assertTrue(error["cast"]["withdrawn"])
        self.assertEqual(error["refused"][0]["reason"], "Knight of Valor: activate only once each turn")
        self.assertNotIn("announcement", error["decision"]["options"])
        # a cost the referee will not pay is refused before it taps
        error = refused({"card": "Fireball", "x": 5, "targets": ["c9"]})
        self.assertEqual(error["cast"]["stage"], "autopay")
        self.assertEqual(error["cast"]["floating_mana"], "C1", "only the Knight's mana floats")
        # refused before anything is sent: X and mode are required, a land is played, a name is checked
        before = len(self.calls())
        for args, flag in (({"card": "Fireball", "targets": ["c9"]}, "x"), ({"card": "Healing Salve", "mode": 2}, "mode"),
                           ({"card": "Lightning Bolt", "x": 2}, "x")):
            self.assertEqual(refused(args)["flag"], flag)
        # a mode the referee does not list as castable now (`usable_modes`): refused with the usable ones
        unusable = refused({"card": "Healing Salve", "mode": "gain 3 life", "targets": ["me"]})
        self.assertEqual((unusable["kind"], unusable["usable_modes"]), ("cast", [1]))
        self.assertIn("mode 0 (Gain 3 life) cannot be cast now — castable now: 1 (Prevent 3 damage)", unusable["message"])
        self.assertIn("is a land — play it with referee_play_land", refused({"card": "Mountain"})["message"])
        missing = refused({"card": "Lightning Blot"})
        self.assertIn("no card 'Lightning Blot'", missing["message"])
        self.assertEqual(missing["suggestions"], ["Lightning Bolt"])
        self.assertIn("Lightning Bolt c2", refused({"card": "Serra Angel"})["castable"])
        self.assertEqual(len(self.calls()), before, "nothing new was started")
        # no mode given: the first castable one; the cost cannot be paid: withdrawn
        error = refused({"card": "Healing Salve", "targets": ["c9"]})
        self.assertEqual(error["sent"][0]["mode"], 1)
        self.assertEqual(error["cast"]["stage"], "autopay")
        self.assertEqual(refused({"card": "Healing Salve", "mode": "Prevent 3 damage", "targets": ["c9"]})["sent"][0]["mode"], 1)
        # in the compact view the refusal's content is the board, headed by the cast's outcome
        compact = self.client.call("referee_cast", {"game": game, "card": "c2", "targets": ["c13"], "view": "compact"})
        self.assertTrue(compact["isError"])
        lines = compact["content"][0]["text"].splitlines()
        self.assertTrue(lines[1].startswith("cast: Lightning Bolt c2 (spell): refused — c13 is not a legal target"), lines[1])
        self.assertEqual(lines[2], "steps: prepare -> cancel")
        self.assertIn("YOUR HAND (5):", lines)
        self.assertEqual(compact["structuredContent"]["error"]["kind"], "target")
        # a divided X spell, the amount laid on its one target
        fireball = self.client.payload("referee_cast", {"game": game, "card": "Fireball", "x": 1, "targets": ["c9"]})
        self.assertEqual(fireball["sent"][-1], {"op": "submit", "targets": [["t3", 1]]})
        self.assertEqual(fireball["cast"]["result"], "cast")
        self.client.payload("referee_stop", {"game": game})

    def test_a_referee_answer_is_the_table_summary_by_default(self):
        # 0.50.13, the owner's question: an agent gets the compact table every
        # turn without asking — `content` is the text whatever `view` the JSON
        # is in; `text: "json"` keeps the JSON as text for a client that wants it.
        opened = self.client.call("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck", "seed": 7})
        state = opened["structuredContent"]
        text = opened["content"][0]["text"]
        self.assertTrue(text.startswith("game %s | decisions 1 | refusals 0\nTURN 1 MAIN1" % state["game"]), text[:120])
        with self.assertRaises(ValueError):
            json.loads(text)
        self.assertIn("YOUR HAND (2):", text.splitlines())
        self.assertIn('  keep: {"op":"keep"}', text.splitlines())
        self.assertTrue(text.splitlines()[-1].startswith("(The full JSON is in structuredContent — the decision in view "
                                                         "`brief`"), text.splitlines()[-1])
        self.assertIn("brief", state["decision"], "structuredContent is unchanged")
        acted = self.client.call("referee_act", {"game": state["game"], "action": {"op": "keep"}})
        self.assertIn("sent: {\"op\": \"keep\", \"seat\": 0}", acted["content"][0]["text"])
        self.assertIn("TURN 1 MAIN1", acted["content"][0]["text"])
        # a result: the end of the game in a line, from this seat's side
        ended = self.client.call("referee_act", {"game": state["game"], "action": {"op": "concede"}})
        self.assertIn("RESULT: you lost — the opponent won (seat 1) | turns 1 | reason concede",
                      ended["content"][0]["text"].splitlines())
        self.assertEqual(ended["content"][0]["text"].splitlines()[-1], "(The full JSON, the result's, is in structuredContent.)")
        stopped = self.client.call("referee_stop", {"game": state["game"]})
        self.assertIn("RESULT: you lost", stopped["content"][0]["text"])
        # the JSON as text, remembered for the game; an unknown word is refused
        raw = self.client.call("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck", "seed": 7, "text": "json"})
        self.assertEqual(json.loads(raw["content"][0]["text"]), raw["structuredContent"])
        game = raw["structuredContent"]["game"]
        again = self.client.call("referee_act", {"game": game, "action": {"op": "keep"}})
        self.assertEqual(json.loads(again["content"][0]["text"]), again["structuredContent"])
        menu = self.client.call("referee_menu", {"game": game})
        self.assertEqual(json.loads(menu["content"][0]["text"]), menu["structuredContent"])
        self.client.payload("referee_stop", {"game": game})
        bad = self.client.call("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck", "text": "yaml"})
        self.assertEqual(bad["structuredContent"]["error"]["flag"], "text")

    def test_referee_start_passes_the_rules_preset(self):
        opened = self.client.payload("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck", "rules": "fifth"})
        self.assertEqual(opened["hello"]["rules"], "fifth")
        self.assertEqual(self.calls()[-1], ["referee", "--deck-a", "a.deck", "--deck-b", "b.deck", "--rules", "fifth"])
        self.client.payload("referee_stop", {"game": opened["game"]})
        plain = self.client.payload("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck"})
        self.assertEqual(plain["hello"]["rules"], "modern_mana_burn")
        self.assertNotIn("--rules", self.calls()[-1])
        self.client.payload("referee_stop", {"game": plain["game"]})

    def test_the_decision_menu_is_numbered_and_picked(self):
        # 0.50.13: referee_menu / referee_pick (tools/decision_menu.py's Driver
        # over the server's own Game) — the opening, then a main phase whose
        # aimed spell is read ahead (a prepare and a cancel, nothing paid) and
        # listed once per legal target.
        game = self.client.payload("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck", "seed": 7})["game"]
        opening = self.client.payload("referee_menu", {"game": game})
        self.assertEqual([i["id"] for i in opening["menu"]], ["order:play", "order:draw"])
        self.assertEqual(opening["obs"]["mode"], "opening")
        self.assertIsInstance(opening["obs"]["features"], list)
        self.assertEqual(opening["n"], 0)
        picked = self.client.payload("referee_pick", {"game": game, "pick": 0})
        self.assertEqual(picked["picked"], {"id": "order:play", "label": "Play first"})
        self.assertEqual(picked["menu"][0]["id"], "pass")
        self.assertIn("play:c1", [i["id"] for i in picked["menu"]])
        # a pick not on the menu: refused with the menu, nothing sent
        before = len(self.calls())
        wrong = self.client.call("referee_pick", {"game": game, "pick": 99})
        self.assertTrue(wrong["isError"])
        error = wrong["structuredContent"]["error"]
        self.assertEqual((error["kind"], error["flag"]), ("option", "pick"))
        self.assertIn("not on the menu", error["message"])
        self.assertIn("play:c1", error["menu"])
        unknown = self.client.call("referee_pick", {"game": game, "pick": "play:c9"})
        self.assertIn("play:c1", unknown["structuredContent"]["error"]["suggestions"])
        bad_until = self.client.call("referee_pick", {"game": game, "pick": 0, "until": "mime"})
        self.assertEqual(bad_until["structuredContent"]["error"]["flag"], "until")
        self.assertEqual(len(self.calls()), before)
        # by its id; the menu answers again with the next one
        land = self.client.payload("referee_pick", {"game": game, "pick": "play:c1"})
        self.assertEqual(land["picked"]["id"], "play:c1")
        self.assertEqual(land["n"], 2)
        # a game the menu touched stays playable by every referee tool
        self.assertIn("decision", self.client.payload("referee_wait", {"game": game}))
        self.client.payload("referee_stop", {"game": game})
        # the cast table: Lightning Bolt read ahead, one item per legal target
        game = self.client.payload("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck", "seed": 41,
                                                     "view": "compact"})["game"]
        menu = self.client.call("referee_menu", {"game": game, "rich": True})
        state = menu["structuredContent"]
        ids = [i["id"] for i in state["menu"]]
        self.assertEqual(ids[0], "pass")
        self.assertEqual(len(ids), len(set(ids)), "ids are unique")
        bolts = [i for i in state["menu"] if i["id"].startswith("cast:c2->")]
        self.assertEqual([i["id"] for i in bolts], ["cast:c2->you", "cast:c2->opp", "cast:c2->c4", "cast:c2->c9",
                                                    "cast:c2->c10", "cast:c2->c11"])   # the phased-out Imp is no target
        self.assertIn("ops", bolts[0])
        self.assertGreaterEqual(state["stats"]["probes"], 1)
        # the probe left nothing announced and nothing tapped
        self.assertNotIn("announcement", self.client.payload("referee_view", {"game": game, "view": "options"})
                         ["decision"]["options"])
        # the compact text is the board and the numbered menu
        lines = menu["content"][0]["text"].splitlines()
        self.assertEqual(lines[0], "game %s | model decisions 0" % game)
        self.assertIn("MENU (answer with referee_pick {pick: N}):", lines)
        self.assertIn("  0. Pass priority  [pass]", lines)
        self.assertNotIn("OPTIONS:", lines)
        self.assertIn("  Teferi's Imp c12 1/1 [PHASED OUT, returns at the opponent's next untap step]", lines)
        aim = next(i for i in state["menu"] if i["id"] == "cast:c2->c9")
        cast = self.client.call("referee_pick", {"game": game, "pick": aim["id"]})
        self.assertFalse(cast["isError"], cast)
        after = cast["structuredContent"]
        self.assertEqual(after["picked"]["id"], "cast:c2->c9")
        self.assertIn("picked: ", cast["content"][0]["text"].splitlines()[1])
        # the pass with `until`: the spell resolves, the server's own stop rule ends the pass
        resolved = self.client.payload("referee_pick", {"game": game, "pick": "pass", "until": "mine"})
        self.assertEqual(resolved["until"], "mine")
        self.assertTrue(resolved["stop"], resolved)
        board = resolved["obs"]["opp"]["battlefield"]
        self.assertNotIn("c9", [c["id"] for c in board], "the Bolt killed the Bears")
        self.assertIn("Lightning Bolt resolves", resolved["obs"]["journal"])
        self.client.payload("referee_stop", {"game": game})

    def test_a_payment_question_leaves_the_cast_open_to_resume(self):
        game = self.client.payload("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck", "seed": 41})["game"]
        asked = self.client.payload("referee_cast", {"game": game, "card": "Chromatic Sphere"})
        self.assertEqual(asked["cast"]["result"], "open")
        self.assertIn("answer it with referee_act", asked["cast"]["note"])
        self.assertEqual(asked["decision"]["mode"], "choice")
        # another card's cast is refused while it is open
        other = self.client.call("referee_cast", {"game": game, "card": "Lightning Bolt", "targets": ["c9"]})
        self.assertTrue(other["isError"])
        answered = self.client.payload("referee_act", {"game": game, "action": {"op": "choice", "picks": [3]}})
        self.assertIn("announcement", answered["decision"]["options"])
        other = self.client.call("referee_cast", {"game": game, "card": "Lightning Bolt", "targets": ["c9"]})
        self.assertIn("is open", other["structuredContent"]["error"]["message"])
        done = self.client.payload("referee_cast", {"game": game, "card": "Chromatic Sphere"})
        self.assertEqual(done["cast"]["result"], "cast")
        self.assertTrue(done["cast"]["resumed"])
        self.assertEqual([s["op"] for s in done["sent"]], ["submit"])
        # the high-level action through referee_act
        cast = self.client.payload("referee_act", {"game": game, "action": {"op": "cast", "card": "Lightning Bolt",
                                                                            "targets": ["opponent"]}})
        self.assertIn("Lightning Bolt", [s["name"] for s in cast["decision"]["brief"]["stack"]])
        self.assertEqual(cast["cast"]["targets"][0]["target"], "player:1")
        self.client.payload("referee_stop", {"game": game})


class WindowsDoorTest(unittest.TestCase):
    """Native release dispatch, without a shell or a Windows host dependency."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="mcp native & space ")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name).resolve()
        self.door = self.home / "Shandalar.console.exe"
        self.door.touch()
        self.server = mcp.Server(self.door, self.home / "workspace")
        self.addCleanup(self.server.shutdown)

    def test_native_verbs_and_arguments_never_go_through_a_shell(self):
        routes = {"lab": ["--deck-lab"], "autodeck": ["--auto-deck"],
                  "referee": ["--referee"], "query": ["--lab-query"],
                  **{v: ["--lab-query", v] for v in ("packs", "cards", "check")}}
        args = ["a deck & other.deck", "Éowyn; $HOME", 'a"b']
        for verb, flags in routes.items():
            with self.subTest(verb=verb), mock.patch.object(mcp.subprocess, "Popen") as popen:
                popen.return_value.communicate.return_value = ("", "")
                popen.return_value.returncode = 0
                done = self.server.run(verb, args, timeout=17)
                self.assertEqual(done.returncode, 0)
                self.assertEqual(popen.call_args.args[0],
                                 [str(self.door), "--headless", "--no-header", "--", *flags, *args])
                self.assertFalse(popen.call_args.kwargs.get("shell", False))
                self.assertEqual(popen.call_args.kwargs["cwd"], str(self.home))
                self.assertLessEqual(popen.return_value.communicate.call_args.kwargs["timeout"], 17)

    def test_referee_uses_the_same_native_route(self):
        with mock.patch.object(mcp, "Game") as game:
            self.server.new_game(["--deck-a", "a & b.deck"], "brief")
            self.assertEqual(game.call_args.args[1],
                             [str(self.door), "--headless", "--no-header", "--",
                              "--referee", "--deck-a", "a & b.deck"])

    def test_release_version_is_metadata_not_the_godot_version(self):
        with mock.patch.object(mcp.subprocess, "run") as run:
            for value, expected in (("9.9.9\n", "9.9.9"), ("1.2.3-rc.1\n", "1.2.3-rc.1"),
                                    ("4.7.2.stable\n", ""), ("garbage", "")):
                (self.home / "VERSION.txt").write_text(value, encoding="utf-8")
                self.assertEqual(mcp.Server(self.door, self.home).version(), expected)
            (self.home / "VERSION.txt").unlink()
            self.assertEqual(self.server.version(), "")
            run.assert_not_called()

    def test_discovery_finds_native_release_without_unix_door(self):
        script = self.home / "tools" / "shandalar_mcp.py"
        with mock.patch.object(mcp, "__file__", str(script)):
            self.assertEqual(mcp.find_door(None), self.door)
            self.assertEqual(mcp.find_door(str(self.door)), self.door)

    def test_native_help_and_unsupported_converter_do_not_boot_the_gui(self):
        with mock.patch.object(mcp.subprocess, "run") as run:
            manual = self.server.tool_manual({"verb": "door"})
            self.assertEqual(manual["exit"], 0)
            self.assertIn("referee", manual["text"])
            for verb in ("convert", "unexpected"):
                with self.assertRaises(mcp.ToolError) as caught:
                    self.server.run(verb, ["in.deck", "out.dck"])
                self.assertEqual(caught.exception.envelope["exit"], 2)
            run.assert_not_called()

    def test_stdio_is_utf8_even_under_a_non_utf8_python_locale(self):
        message = {"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {
            "name": "write_deck", "arguments": {"file": "unicode.deck", "name": "Žarek 魔法",
                                                   "cards": ["20 Mountain"], "check": False}}}
        done = subprocess.run([sys.executable, str(SERVER), "--door", str(self.door)],
                              input=json.dumps(message, ensure_ascii=False) + "\n",
                              capture_output=True, text=True, encoding="utf-8", timeout=20,
                              env={**os.environ, "PYTHONIOENCODING": "ascii"})
        self.assertEqual(done.returncode, 0, done.stderr)
        answer = json.loads(done.stdout)["result"]
        self.assertFalse(answer["isError"], answer)
        self.assertEqual(answer["structuredContent"]["name"], "Žarek 魔法")

    @unittest.skipIf(os.name == "nt", "POSIX executable stand-in; native argument tests run everywhere")
    def test_native_pipe_covers_tools_and_a_live_referee_session(self):
        # Simulate the packaged PE's argument boundary, not a Windows runtime.
        adapter = '''args = sys.argv[1:]
assert args[:3] == ["--headless", "--no-header", "--"], args
args = args[3:]
flag = args.pop(0)
verb = {"--deck-lab": "lab", "--auto-deck": "autodeck", "--referee": "referee"}.get(flag)
if flag == "--lab-query":
    verb = args.pop(0)
assert verb is not None, flag
args = [verb, *args]'''
        self.door.write_text(FAKE_DOOR.replace("args = sys.argv[1:]", adapter), encoding="utf-8")
        self.door.chmod(0o755)
        (self.home / "VERSION.txt").write_text("9.9.9\n", encoding="utf-8")
        client = Client(self.door, self.home / "workspace")
        try:
            self.assertEqual(client.ask("initialize")["result"]["serverInfo"]["version"], "9.9.9")
            self.assertIn("packs", client.payload("packs"))
            self.assertTrue(client.payload("cards", {"names": ["Lightning Bolt"]})["cards"][0]["known"])
            written = client.payload("write_deck", {"file": "red & green.deck", "name": "Éowyn",
                                                     "cards": ["4 Lightning Bolt", "20 Mountain"]})
            self.assertTrue(written["playable"])
            self.assertEqual(client.payload("read_deck", {"deck": "red & green.deck"})["name"], "Éowyn")
            self.assertTrue(client.payload("check_deck", {"decks": ["red & green.deck"]})["playable"])
            self.assertEqual(client.payload("lab", {"deck_a": "red & green.deck", "deck_b": "b.deck",
                                                     "out": "workspace/run"})["exit"], 0)
            self.assertEqual(client.payload("autodeck", {"out": "workspace/field", "count": 2})["count"], 2)
            opened = client.payload("referee_start", {"deck_a": "red & green.deck", "deck_b": "b.deck"})
            self.assertEqual(opened["decision"]["mode"], "opening")
            ended = client.payload("referee_act", {"game": opened["game"], "action": {"op": "concede"}})
            self.assertEqual(ended["result"]["reason"], "concede")
        finally:
            stderr = client.close()
        self.assertEqual(stderr, "")
        calls = [json.loads(line) for line in (self.home / "calls.log").read_text().splitlines()]
        self.assertTrue(calls)
        self.assertTrue(all(args[:3] == ["--headless", "--no-header", "--"] for args in calls))


class ShutdownTest(unittest.TestCase):
    """A server whose stdin closes ends every game it opened."""

    def test_games_end_with_the_server(self):
        with tempfile.TemporaryDirectory(prefix="shandalar-mcp-") as tmp:
            home = Path(tmp)
            door = home / "shandalar.sh"
            door.write_text(FAKE_DOOR, encoding="utf-8")
            door.chmod(0o755)
            client = Client(door, home / "ws")
            client.ask("initialize", {"protocolVersion": "2025-06-18"})
            opened = client.payload("referee_start", {"deck_a": "a", "deck_b": "b"})
            self.assertEqual(opened["decision"]["n"], 0)
            stderr = client.close()
            self.assertEqual(client.proc.returncode, 0, stderr)
            time.sleep(0.5)
            log = (home / "ws" / "games" / "g1.stderr")
            self.assertTrue(log.is_file())


class KeptGameTest(unittest.TestCase):
    """A kept game: the referee listens on the loopback and outlives the
    server; another server takes it up with the whole journal; one that
    ended alone is told from its transcript; one whose referee is gone
    is a clear refusal and is forgotten."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="shandalar-mcp-kept-")
        self.home = Path(self.tmp.name)
        self.door = self.home / "shandalar.sh"
        self.door.write_text(FAKE_DOOR, encoding="utf-8")
        self.door.chmod(0o755)
        self.workspace = self.home / "ws"
        self.games = self.workspace / "games"

    def tearDown(self):
        self.tmp.cleanup()

    def open_client(self) -> Client:
        client = Client(self.door, self.workspace)
        client.ask("initialize", {"protocolVersion": "2025-06-18"})
        return client

    @staticmethod
    def alive(pid: int) -> bool:
        try:
            os.kill(pid, 0)
        except OSError:
            return False
        # a child of a server that closed is reaped by nobody until it is waited for
        try:
            return os.waitpid(pid, os.WNOHANG) == (0, 0)
        except ChildProcessError:
            return True

    def test_a_kept_game_survives_the_server(self):
        client = self.open_client()
        opened = client.payload("referee_start", {"deck_a": "a.deck", "deck_b": "b.deck", "keep": True})
        game = opened["game"]
        self.assertEqual(opened["decision"]["n"], 0)
        self.assertEqual(opened["hello"]["seed"], 7)
        record = json.loads((self.games / (game + ".json")).read_text(encoding="utf-8"))
        self.assertEqual(record["game"], game)
        self.assertEqual(record["command"][-4:-2], ["--listen", str(self.games / (game + ".keep.json"))])
        handshake = json.loads((self.games / (game + ".keep.json")).read_text(encoding="utf-8"))
        pid = int(handshake["pid"])
        self.assertEqual(len(handshake["token"]), 32)
        first = client.payload("referee_act", {"game": game, "action": "default"})
        self.assertEqual(first["decision"]["n"], 1)
        row = [g for g in client.payload("status")["games"] if g["game"] == game][0]
        self.assertTrue(row["kept"])
        listing = client.payload("referee_resume", {})
        self.assertEqual(listing["kept"], [])
        self.assertEqual(listing["games"][0]["game"], game)
        # the server goes; the referee stays, listening
        stderr = client.close()
        self.assertEqual(client.proc.returncode, 0, stderr)
        self.assertTrue(self.alive(pid))
        again = self.open_client()
        listing = again.payload("referee_resume", {})
        self.assertEqual([k["game"] for k in listing["kept"]], [game])
        self.assertEqual(listing["kept"][0]["note"], "referee_resume takes it up")
        self.assertEqual(listing["games"], [])
        none = again.call("referee_resume", {"game": "g9"})
        self.assertTrue(none["isError"])
        self.assertEqual(none["structuredContent"]["error"]["kept"], [game])
        resumed = again.payload("referee_resume", {"game": game, "view": "brief"})
        self.assertTrue(resumed["resumed"])
        self.assertEqual(resumed["hello"]["seed"], 7)
        self.assertEqual(resumed["decision"]["n"], 1)
        self.assertEqual(resumed["decisions"], 2)
        self.assertEqual(resumed["decision"]["brief"]["journal"], ["Toss: seat 0 plays first"])
        # taken up: the game is this server's now, and plays on
        same = again.payload("referee_resume", {"game": game})
        self.assertEqual(same["decision"]["n"], 1)
        self.assertNotIn("resumed", same)
        passed = again.payload("referee_act", {"game": game, "action": {"op": "pass"}})
        self.assertEqual(passed["decision"]["n"], 2)
        self.assertEqual(passed["decisions"], 3)
        stopped = again.payload("referee_stop", {"game": game})
        self.assertEqual(stopped["result"]["reason"], "concede")
        self.assertEqual(stopped["result"]["decisions"], 3)
        self.assertFalse((self.games / (game + ".json")).is_file())
        # still this server's game, finished; another server knows it no more
        gone = again.payload("referee_resume", {"game": game})
        self.assertEqual(gone["result"]["reason"], "concede")
        self.assertNotIn("decision", gone)
        again.close()
        third = self.open_client()
        none = third.call("referee_resume", {"game": game})
        self.assertTrue(none["isError"])
        self.assertIn("no kept game", none["structuredContent"]["error"]["message"])
        self.assertEqual(third.payload("referee_start", {"deck_a": "a", "deck_b": "b"})["game"], "g2")
        third.close()
        deadline = time.time() + 10
        while self.alive(pid) and time.time() < deadline:
            time.sleep(0.1)
        self.assertFalse(self.alive(pid))
        lines = (self.games / (game + ".lines")).read_text(encoding="utf-8").splitlines()
        self.assertEqual([json.loads(l)["type"] for l in lines], ["hello", "decision", "decision", "decision", "result"])

    def test_a_hosted_table_is_taken_up_with_its_table_line(self):
        # the server goes while the chair is still empty; the next one is
        # told the table first, then the duel that started meanwhile
        client = self.open_client()
        opened = client.payload("referee_host", {"table": "Kitchen", "deck": "a.deck", "wait": 77})
        game = opened["game"]
        self.assertTrue(opened["pending"])
        self.assertEqual(opened["table"]["name"], "Kitchen")
        pid = int(json.loads((self.games / (game + ".keep.json")).read_text(encoding="utf-8"))["pid"])
        stderr = client.close()
        self.assertEqual(client.proc.returncode, 0, stderr)
        self.assertTrue(self.alive(pid))
        again = self.open_client()
        resumed = again.payload("referee_resume", {"game": game, "timeout": 30})
        self.assertTrue(resumed["resumed"])
        self.assertEqual(resumed["decision"]["n"], 0)
        self.assertEqual(resumed["hello"]["table"], {"id": "r1", "name": "Kitchen", "seat": 0, "hosted": True})
        self.assertNotIn("table", resumed)
        row = [g for g in again.payload("status")["games"] if g["game"] == game][0]
        self.assertEqual(row["hosted"]["access"], "open")
        stopped = again.payload("referee_stop", {"game": game})
        self.assertEqual(stopped["result"]["reason"], "concede")
        again.close()
        lines = (self.games / (game + ".lines")).read_text(encoding="utf-8").splitlines()
        self.assertEqual([json.loads(l)["type"] for l in lines][:3], ["table", "hello", "decision"])

    def test_a_kept_game_that_ended_alone_or_lost_its_referee_is_told(self):
        self.games.mkdir(parents=True)
        def record(ident: str, lines: list) -> dict:
            rec = {"game": ident, "argv": ["--deck-a", "a", "--deck-b", "b"], "view": "brief",
                   "keep": str(self.games / f"{ident}.keep.json"), "lines": str(self.games / f"{ident}.lines"),
                   "stderr": str(self.games / f"{ident}.stderr"), "started": 1.0,
                   "command": [str(self.door), "referee", "--deck-a", "a", "--deck-b", "b"]}
            (self.games / f"{ident}.json").write_text(json.dumps(rec), encoding="utf-8")
            (self.games / f"{ident}.lines").write_text("".join(json.dumps(l) + "\n" for l in lines), encoding="utf-8")
            return rec
        record("g7", [{"type": "hello", "seed": 1}, {"type": "decision", "n": 0},
                      {"type": "result", "winner": 1, "reason": "idle", "decisions": 1, "refusals": 0}])
        record("g8", [{"type": "hello", "seed": 2}, {"type": "decision", "n": 0}])
        stale = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        stale.bind(("127.0.0.1", 0))
        port = stale.getsockname()[1]
        stale.close()
        (self.games / "g8.keep.json").write_text(json.dumps({"port": port, "token": "x" * 32, "pid": 1, "version": "9.9.9"}), encoding="utf-8")
        (self.games / "g9.json").write_text("not json", encoding="utf-8")
        client = self.open_client()
        listing = client.payload("referee_resume", {})
        self.assertEqual([(k["game"], k.get("result", {}).get("reason"), k.get("note")) for k in listing["kept"]],
                         [("g7", "idle", None), ("g8", None, "referee_resume takes it up")])
        ended = client.payload("referee_resume", {"game": "g7"})
        self.assertEqual(ended["result"]["reason"], "idle")
        self.assertEqual(ended["lines"], str(self.games / "g7.lines"))
        self.assertFalse((self.games / "g7.json").is_file())
        self.assertTrue((self.games / "g7.lines").is_file())
        started = time.time()
        lost = client.call("referee_resume", {"game": "g8"})
        self.assertTrue(lost["isError"])
        error = lost["structuredContent"]["error"]
        self.assertEqual(error["kind"], "keep")
        self.assertIn("did not take the connection", error["message"])
        self.assertEqual(error["lines"], str(self.games / "g8.lines"))
        self.assertLess(time.time() - started, mcp.KEEP_RESUME + 5)
        self.assertFalse((self.games / "g8.json").is_file())
        self.assertEqual(client.payload("referee_resume", {})["kept"], [])
        # a new game is numbered past every file in the folder — nothing is written over
        opened = client.payload("referee_start", {"deck_a": "a", "deck_b": "b"})
        self.assertEqual(opened["game"], "g10")
        client.close()


class UnitTest(unittest.TestCase):
    """The pieces without a process: the deck reader, the brief view,
    the pilot, the pass-until stops, the delta."""

    def test_a_decision_without_a_choice_is_answered_by_the_smooth_modes(self):
        # 2026-10-04: until mine stopped at "attack: nothing can attack".
        attack = {"mode": "attack", "seat": 0, "options": {"attack": {"attackable": []}}}
        self.assertEqual(mcp.no_choice_answer(attack), {"op": "attack", "cards": [], "seat": 0})
        block = {"mode": "block", "seat": 1, "options": {"block": {"blockable": []}}}
        self.assertEqual(mcp.no_choice_answer(block), {"op": "block", "pairs": [], "seat": 1})
        live = {"mode": "attack", "seat": 0, "options": {"attack": {"attackable": [{"card": "c6"}]}}}
        self.assertIsNone(mcp.no_choice_answer(live))
        self.assertIsNone(mcp.no_choice_answer({"mode": "priority", "seat": 0, "options": {}}))
        self.assertIsNone(mcp.no_choice_answer(None))
        # an options shape without the list is never read as "nothing can"
        self.assertIsNone(mcp.no_choice_answer({"mode": "block", "seat": 0, "options": {"block": {"blockers": []}}}))

    def test_parse_deck_reads_like_the_engine(self):
        # engine/deck_list.gd, rule for rule (2026-10-03).
        parsed = mcp.parse_deck("\ufeff// NAME : Spaced\n4x Lightning Bolt\n4 x Card\n0 Island\nName: Wrong\n")
        self.assertEqual(parsed["name"], "Spaced")
        self.assertEqual(parsed["main"], [{"count": 4, "name": "Lightning Bolt"}, {"count": 4, "name": "x Card"}])
        self.assertEqual(parsed["errors"], ["0 Island", "Name: Wrong"])
        self.assertEqual(mcp.parse_deck("// Nameless idea: not a title\nname: Kept\n")["name"], "Kept")

    def test_parse_deck(self):
        parsed = mcp.parse_deck("# a comment\n// NAME: Old\nname: New\n4x Lightning Bolt\n20 Mountain\nSB: 3 Pyroblast\nnonsense\n")
        self.assertEqual(parsed["name"], "New")
        self.assertEqual(parsed["cards"], 24)
        self.assertEqual(parsed["sideboard_cards"], 3)
        self.assertEqual(parsed["errors"], ["nonsense"])
        self.assertEqual(parsed["main"][0], {"count": 4, "name": "Lightning Bolt"})

    def test_deck_rows(self):
        self.assertEqual(mcp.deck_rows("4 Bolt\n1x Island", "t", "cards"),
                         [{"count": 4, "name": "Bolt"}, {"count": 1, "name": "Island"}])
        self.assertEqual(mcp.deck_rows([{"name": "Island"}], "t", "cards"), [{"count": 1, "name": "Island"}])
        with self.assertRaises(mcp.ToolError):
            mcp.deck_rows([{"count": "x", "name": "Island"}], "t", "cards")
        with self.assertRaises(mcp.ToolError):
            mcp.deck_rows(["0 Island"], "t", "cards")
        with self.assertRaises(mcp.ToolError):
            mcp.deck_rows(7, "t", "cards")

    def test_pilot(self):
        memory = {}
        self.assertEqual(mcp.default_answer({"mode": "opening", "options": {"keep": {}}, "view": {}}, memory), {"op": "keep"})
        self.assertEqual(mcp.default_answer({"mode": "block", "options": {}, "view": {}}, memory), {"op": "block", "pairs": []})
        attack = mcp.default_answer({"mode": "attack", "options": {"attack": {"attackable": [{"card": "c1"}, {"card": "c2"}]}}, "view": {}}, memory)
        self.assertEqual(attack["cards"], ["c1", "c2"])
        damage = mcp.default_answer({"mode": "damage", "options": {"damage": {"request": {"amount": 5, "targets": [{"id": "c1", "lethal": 2}, {"id": "player", "lethal": 20}]}}}, "view": {}}, memory)
        self.assertEqual(damage["points"], [["c1", 2], ["player", 3]])
        discard = mcp.default_answer({"mode": "discard", "options": {"discard": {"count": 1, "hand": [{"card": "c3"}, {"card": "c4"}]}}, "view": {}}, memory)
        self.assertEqual(discard["cards"], ["c3"])
        announce = {"mode": "priority", "seat": 0, "view": {"turn": 2},
                    "options": {"announcement": {"slots": [{"min": 1, "targets": [{"id": "player1"}]}]}, "draft": {"card": "c2", "reachable": True}}}
        self.assertEqual(mcp.default_answer(announce, memory), {"op": "autopay", "excluded": [], "count": 1})
        self.assertEqual(mcp.default_answer(announce, memory), {"op": "submit", "targets": [["player1", 0]]})
        priority = {"mode": "priority", "seat": 0, "view": {"turn": 2, "step": "MAIN1", "active": 0, "stack": []},
                    "options": {"play": {"lands": []}, "prepare": {"casts": [{"card": "c5", "x": True}, {"card": "c6", "x": False}]}}}
        self.assertEqual(mcp.default_answer(priority, memory)["card"], "c6")
        self.assertEqual(mcp.default_answer(priority, memory), {"op": "pass"})
        # a payment whose tap put a trigger on the stack (City of Brass) is cancelled —
        # the sorcery is prepared again once the trigger has resolved, paid from the pool
        memory = {}
        self.assertEqual(mcp.default_answer(priority, memory)["op"], "prepare")
        paying = {"mode": "priority", "seat": 0,
                  "view": {"turn": 2, "step": "MAIN1", "active": 0, "stack": [],
                           "presentation": {"cards": [{"id": "c6", "castable": True}]}},
                  "options": {"announcement": {"slots": []}, "draft": {"card": "c6", "reachable": True}}}
        self.assertEqual(mcp.default_answer(paying, memory)["op"], "autopay")
        struck_by_brass = dict(paying, view=dict(paying["view"], stack=[{"name": "City of Brass"}],
                                                presentation={"cards": [{"id": "c6", "castable": False}]}))
        self.assertEqual(mcp.default_answer(struck_by_brass, memory), {"op": "cancel"})
        self.assertEqual(mcp.default_answer(dict(priority, view=dict(priority["view"], stack=[{"name": "City of Brass"}])), memory), {"op": "pass"})
        self.assertEqual(mcp.default_answer(priority, memory), {"op": "prepare", "card": "c6", "kind": "spell", "index": 0, "x": 0, "mode": 0})
        self.assertEqual(mcp.default_answer(paying, memory)["op"], "autopay")
        self.assertEqual(mcp.default_answer(paying, memory), {"op": "submit", "targets": []})
        # an instant the referee still lists as castable over the trigger is submitted as it is
        memory = {}
        self.assertEqual(mcp.default_answer(paying, memory)["op"], "autopay")
        over_a_trigger = dict(paying, view=dict(paying["view"], stack=[{"name": "Manabarbs"}]))
        self.assertEqual(mcp.default_answer(over_a_trigger, memory), {"op": "submit", "targets": []})
        self.assertFalse(mcp.castable_now({}, "c6"))
        # a decision the referee refused an answer to gets the quiet answer, the third refusal concedes
        struck = {"strikes": {16: 1}}
        self.assertEqual(mcp.default_answer(dict(announce, n=16), struck), {"op": "cancel"})
        self.assertEqual(mcp.default_answer(dict(priority, n=16), struck), {"op": "pass"})
        self.assertEqual(mcp.default_answer(dict({"mode": "attack", "n": 16, "options": {"attack": {"attackable": [{"card": "c1"}]}}, "view": {}}), struck), {"op": "attack", "cards": []})
        self.assertEqual(mcp.default_answer(dict(announce, n=17), struck)["op"], "autopay")
        self.assertEqual(mcp.default_answer(dict(announce, n=16), {"strikes": {16: 3}}), {"op": "concede"})

    def test_stop_reason_names_where_a_player_acts(self):
        def decision(step, active=0, respond=False, stack=None, mode="priority", attacking=False, turn=2, **options):
            view = {"turn": turn, "step": step, "active": active, "stack": stack or [],
                    "players": [{"seat": 0, "battlefield": []},
                                {"seat": 1, "battlefield": [{"id": "c9", "name": "Bears", "attacking": attacking}]}]}
            opts = {"mode": mode, "pass": {"op": "pass"}, "respond": respond, "play": {"lands": []}, "prepare": {"casts": []}}
            opts.update(options)
            return {"n": 1, "seat": 0, "mode": mode, "turn": turn, "step": step, "options": opts, "view": view}
        origin = {"turn": 2, "step": "MAIN1"}
        stop = mcp.stop_reason
        # never passed, whatever `until` says
        for until in mcp.UNTIL:
            self.assertEqual(stop(decision("DECLARE_BLOCKERS", mode="block"), until, origin), "decision: block")
            self.assertEqual(stop(decision("MAIN1", announcement={"slots": []}), until, origin), "a cast is in progress")
        # every value but the smart ones stops at a reaction window on `respond` alone
        for until in ("main", "end", "turn", "respond", "play"):
            self.assertEqual(stop(decision("MAIN1", active=1, respond=True, stack=[{"name": "Terror", "controller": 1}]), until, origin),
                             "the opponent's Terror is on the stack and you can respond")
            self.assertEqual(stop(decision("END", active=1, respond=True), until, origin), "their end: you can respond")
            self.assertEqual(stop(decision("DECLARE_ATTACKERS", active=1, respond=True, attacking=True), until, origin),
                             "their declare attackers: you can respond")
            self.assertEqual(stop(decision("DECLARE_BLOCKERS", respond=True), until, origin), "your declare blockers: you can respond")
        # the seat's own spell on the stack, their beginning of combat, attackers not yet
        # declared, a window with nothing to respond with: passed
        self.assertEqual(stop(decision("MAIN1", active=1, respond=True, stack=[{"name": "Bolt", "controller": 0}]), "turn", origin), "")
        self.assertEqual(stop(decision("COMBAT_BEGIN", active=1, respond=True), "turn", origin), "")
        self.assertEqual(stop(decision("DECLARE_ATTACKERS", active=1, respond=True), "turn", origin), "")
        self.assertEqual(stop(decision("END", active=1), "turn", origin), "")
        self.assertEqual(stop(decision("DECLARE_BLOCKERS"), "end", origin), "")
        # the named stops
        self.assertEqual(stop(decision("MAIN2"), "main", origin), "your main phase")
        self.assertEqual(stop(decision("MAIN1", stack=[{"name": "Bolt", "controller": 0}]), "main", origin), "")
        self.assertEqual(stop(decision("MAIN1", active=1), "main", origin), "")
        self.assertEqual(stop(decision("MAIN2"), "turn", origin), "")
        self.assertEqual(stop(decision("MAIN1", turn=3), "turn", origin), "your turn")
        self.assertEqual(stop(decision("END"), "end", origin), "the end step")
        self.assertEqual(stop(decision("UPKEEP", active=1, turn=3), "end", origin), "the next turn began")
        self.assertEqual(stop(decision("MAIN2"), "play", origin), "")
        self.assertEqual(stop(decision("MAIN2", play={"lands": [{"card": "c1"}]}), "play", origin), "your main phase, with something to play")
        self.assertEqual(stop(decision("MAIN2", prepare={"casts": [{"card": "c2"}]}), "play", origin), "your main phase, with something to play")
        self.assertEqual(stop(decision("MAIN2", special={"specials": [{"id": "s"}]}), "play", origin), "your main phase, with something to play")

    def test_delta_view_shows_what_moved(self):
        before = {"turn": 2, "step": "MAIN1", "active": 0, "actor": 0, "seat": 0,
                  "players": [{"seat": 0, "life": 20, "hand": 7, "library": 50, "battlefield": [{"id": "c1", "name": "Mountain", "land": True}],
                               "graveyard": ["Bolt"]},
                              {"seat": 1, "life": 20, "hand": 7, "library": 50, "battlefield": [{"id": "c9", "name": "Bears", "pt": "2/2"}]}],
                  "hand": [{"id": "c2", "name": "Bolt", "castable": True}, {"id": "c3", "name": "Island", "land": True}],
                  "journal": ["one"]}
        self.assertEqual(mcp.delta_view(None, before), {**before, "baseline": True})
        now = {"turn": 2, "step": "MAIN2", "active": 0, "actor": 0, "seat": 0,
               "players": [{"seat": 0, "life": 17, "hand": 6, "library": 50,
                            "battlefield": [{"id": "c1", "name": "Mountain", "land": True, "tapped": True}, {"id": "c3", "name": "Island", "land": True}],
                            "graveyard": ["Bolt", "Bolt"], "mana": "{R}"},
                           {"seat": 1, "life": 20, "hand": 7, "library": 50, "battlefield": []}],
               "hand": [{"id": "c2", "name": "Bolt", "castable": False}, {"id": "c4", "name": "Giant Growth"}],
               "journal": ["two", "three"], "stack": [{"name": "Bears", "controller": 1}]}
        delta = mcp.delta_view(before, now)
        self.assertEqual(delta["players"], [
            {"seat": 0, "life": 17, "life_was": 20, "hand": 6, "hand_was": 7,
             "battlefield_added": [{"id": "c3", "name": "Island", "land": True}],
             "battlefield_changed": [{"id": "c1", "name": "Mountain", "land": True, "tapped": True}],
             "graveyard_added": ["Bolt"], "mana": "{R}"},
            {"seat": 1, "battlefield_gone": ["Bears (c9)"]}])
        self.assertEqual(delta["hand_added"], [{"id": "c4", "name": "Giant Growth"}])
        self.assertEqual(delta["hand_gone"], ["Island (c3)"])
        self.assertEqual(delta["hand_changed"], [{"id": "c2", "name": "Bolt", "castable": False}])
        self.assertEqual(delta["castable"], [])
        self.assertEqual(delta["journal"], ["two", "three"])
        self.assertEqual(delta["stack"][0]["name"], "Bears")
        self.assertEqual((delta["turn"], delta["step"]), (2, "MAIN2"))
        self.assertNotIn("baseline", delta)
        # nothing moved: the clock, the castable names and the journal alone
        still = mcp.delta_view(now, now)
        self.assertEqual(sorted(still), ["active", "actor", "castable", "journal", "seat", "stack", "step", "turn"])

    def test_brief_view_is_small(self):
        view = {"turn": 3, "step": "MAIN1", "active": 0, "actor": 0, "stack": [], "winner": -1,
                "hand": [{"id": "c1", "name": "Island", "land": True, "rules": "T: add U"}],
                "players": [{"seat": 0, "deck_name": "A", "life": 20, "hand_count": 1, "library_count": 50, "mana": "{U}",
                             "battlefield": [{"id": "c7", "name": "Serra Angel", "creature": True, "power": 4, "toughness": 4,
                                              "tapped": True, "rules": "Flying, vigilance", "keywords": [1, 2]}],
                             "graveyard": [{"id": "c8", "name": "Counterspell"}], "exile": []}],
                "journal": [{"text": "one", "turn": 3}, "two"], "presentation": {"cards": [], "packets": ["x"] * 100}}
        brief = mcp.brief_view(view, 0)
        self.assertEqual(brief["players"][0]["graveyard"], ["Counterspell"])
        self.assertEqual(brief["players"][0]["battlefield"][0], {"id": "c7", "name": "Serra Angel", "pt": "4/4", "tapped": True, "rules": "Flying, vigilance"})
        self.assertEqual(brief["hand"][0], {"id": "c1", "name": "Island", "land": True})
        self.assertEqual(brief["journal"], ["one", "two"])
        self.assertNotIn("winner", brief)
        self.assertNotIn("presentation", json.dumps(brief))

    # --- 0.50.13: what the 2026-10-04 play-through could not see or do ----

    PHASING_VIEW = {
        "turn": 4, "step": "MAIN1", "active": 0, "actor": 0, "mode": "priority", "winner": -1,
        "stack": [{"name": "Lightning Bolt", "controller": 1, "details": "Spell", "x": 0,
                   "targets": ["Knight of Valor — yours"]}],
        "hand": [{"id": "c2", "name": "Swords to Plowshares", "land": False},
                 {"id": "c8", "name": "Plains", "land": True, "playable": True}],
        "players": [
            {"seat": 0, "deck_name": "Knights", "life": 18, "hand_count": 2, "library_count": 41, "mana": 1,
             "mana_colors": [1, 0, 0, 0, 0, 0],
             "battlefield": [{"id": "c1", "name": "Plains", "land": True, "tapped": True},
                             {"id": "c4", "name": "Knight of Valor", "creature": True, "power": 2, "toughness": 2,
                              "attacking": True, "damage": 1, "counters": {"+1/+1": 1}, "controller": 0},
                             {"id": "c14", "name": "Holy Strength", "attached": "c4", "controller": 0}],
             "phased_out": [{"id": "c5", "name": "Grizzly Bears", "creature": True, "power": 2, "toughness": 2,
                             "tapped": True, "controller": 0},
                            {"id": "c15", "name": "Unholy Strength", "attached": "c5", "controller": 0}],
             "graveyard": [{"id": "c20", "name": "Shock"}], "exile": []},
            {"seat": 1, "deck_name": "Phasing", "life": 20, "hand_count": 5, "library_count": 40,
             "battlefield": [{"id": "c9", "name": "Oubliette", "controller": 1}],
             "phased_out": [{"id": "c12", "name": "Teferi's Imp", "creature": True, "power": 1, "toughness": 1,
                             "controller": 1},
                            {"id": "c13", "name": "Serra Angel", "creature": True, "power": 4, "toughness": 4,
                             "controller": 0}],
             "graveyard": [], "exile": []}],
        "journal": [{"text": "Wizard casts Lightning Bolt", "serial": 9}],
        "presentation": {"cards": [{"id": "c2", "castable": True, "abilities": [{"kind": "spell", "index": 0, "cost": "{W}"}]},
                                   {"id": "c15", "flags": {"phased_out": True, "phased_indirectly": True}}],
                         "phase_holds": [["c13", "c9"]]}}

    def test_brief_view_shows_phased_out_and_attachments(self):
        brief = mcp.brief_view(self.PHASING_VIEW, 0)
        mine, theirs = brief["players"]
        self.assertEqual(mine["battlefield"][2], {"id": "c14", "name": "Holy Strength", "attached": "c4",
                                                  "attached_name": "Knight of Valor"})
        self.assertEqual(mine["phased_out"][0], {"id": "c5", "name": "Grizzly Bears", "pt": "2/2", "tapped": True,
                                                 "phased_out": True, "returns": "returns at your next untap step"})
        self.assertEqual(mine["phased_out"][1]["returns"], "phases in with Grizzly Bears (c5)")
        self.assertEqual(mine["phased_out"][1]["attached_name"], "Grizzly Bears")
        self.assertEqual(theirs["phased_out"][0]["returns"], "returns at the opponent's next untap step")
        self.assertEqual(theirs["phased_out"][1]["returns"],
                         "held by Oubliette (c9): phases in when it leaves the battlefield")
        # the opponent's seat sees the same table from its side
        self.assertEqual(mcp.brief_view(self.PHASING_VIEW, 1)["players"][1]["phased_out"][0]["returns"],
                         "returns at your next untap step")
        # a player with nothing phased out has no key
        self.assertNotIn("phased_out", mcp.brief_view({"players": [{"seat": 0, "battlefield": []}]}, 0)["players"][0])

    def test_delta_view_shows_phasing_and_attachments(self):
        before = mcp.brief_view(self.PHASING_VIEW, 0)
        later = json.loads(json.dumps(self.PHASING_VIEW))
        me = later["players"][0]
        # the Bears phase in (and the Aura with them); Holy Strength moves to the Bears
        me["battlefield"].append(me["phased_out"].pop(0))
        me["battlefield"].append(me["phased_out"].pop(0))
        me["battlefield"][2]["attached"] = "c5"
        later["players"][1]["phased_out"].append({"id": "c16", "name": "Ertai's Familiar", "creature": True,
                                                   "power": 2, "toughness": 2, "controller": 1})
        delta = mcp.delta_view(before, mcp.brief_view(later, 0))
        mine, theirs = delta["players"]
        self.assertEqual(mine["phased_out_gone"], ["Grizzly Bears (c5)", "Unholy Strength (c15)"])
        self.assertEqual([c["id"] for c in mine["battlefield_added"]], ["c5", "c15"])
        self.assertEqual(mine["attached_changed"], [{"id": "c14", "name": "Holy Strength",
                                                     "to": "Grizzly Bears (c5)", "from": "Knight of Valor (c4)"}])
        self.assertEqual(theirs["phased_out_added"][0]["name"], "Ertai's Familiar")
        self.assertEqual(theirs["phased_out_added"][0]["returns"], "returns at the opponent's next untap step")

    def test_mine_stops_only_where_the_seat_holds_something(self):
        def decision(step, active=1, respond=False, stack=None, mode="priority", attacking=False, casts=(),
                     abilities=(), lands=()):
            view = {"turn": 2, "step": step, "active": active, "stack": stack or [],
                    "players": [{"seat": 0, "battlefield": [{"id": "c4", "attacking": attacking and active == 0}]},
                                {"seat": 1, "battlefield": [{"id": "c9", "attacking": attacking and active == 1}]}]}
            opts = {"mode": mode, "pass": {"op": "pass"}, "respond": respond, "play": {"lands": list(lands)},
                    "prepare": {"casts": list(casts), "abilities": list(abilities)}, "special": {"specials": []}}
            return {"n": 1, "seat": 0, "mode": mode, "turn": 2, "step": step, "options": opts, "view": view}
        stop = mcp.stop_reason
        origin = {"turn": 2}
        bolt = [{"card": "c2", "name": "Disenchant", "x": False}]
        terror = {"name": "Terror", "controller": 1}
        # holding a castable instant: their spell stops, and says what is held
        self.assertEqual(stop(decision("MAIN1", respond=True, stack=[terror], casts=bolt), "mine", origin),
                         "their Terror is on the stack; you hold Disenchant (castable)")
        # holding only a sorcery (never listed on their turn), or an exhausted
        # once-per-turn ability (not listed — or marked, by a referee that marks)
        self.assertEqual(stop(decision("MAIN1", respond=False, stack=[terror]), "mine", origin), "")
        self.assertEqual(stop(decision("MAIN1", respond=True, stack=[terror]), "mine", origin), "")
        spent = [{"card": "c4", "name": "Knight of Valor", "index": 1, "cost": "{1}{W}", "usable": False}]
        self.assertEqual(stop(decision("END", respond=True, abilities=spent), "mine", origin), "")
        self.assertEqual(mcp.usable_now({"respond": True, "prepare": {"abilities": spent}}), [])
        # a castable instant with nothing to aim at (`respond` false) is not held
        self.assertEqual(stop(decision("END", respond=False, casts=bolt), "mine", origin), "")
        # a legal non-mana ability is held on its own
        sorcerer = [{"card": "c6", "name": "Prodigal Sorcerer", "index": 0, "cost": "{T}"}]
        self.assertEqual(stop(decision("END", abilities=sorcerer), "mine", origin),
                         "their end; you hold Prodigal Sorcerer's ability {T}")
        self.assertEqual(stop(decision("DECLARE_ATTACKERS", respond=True, casts=bolt, attacking=True), "mine", origin),
                         "their declare attackers; you hold Disenchant (castable)")
        self.assertEqual(stop(decision("DECLARE_ATTACKERS", respond=True, casts=bolt), "mine", origin), "",
                         "before attackers are declared")
        self.assertEqual(stop(decision("COMBAT_BEGIN", respond=True, casts=bolt), "mine", origin), "")
        self.assertEqual(stop(decision("UPKEEP", respond=True, casts=bolt), "mine", origin), "")
        # the seat's own spell on top is let resolve
        self.assertEqual(stop(decision("MAIN1", respond=True, casts=bolt, stack=[{"name": "Shock", "controller": 0}]),
                              "mine", origin), "")
        # the own turn: the main phase with something to do, the blocks of the own attack while holding
        self.assertEqual(stop(decision("MAIN1", active=0, lands=[{"card": "c8"}]), "mine", origin),
                         "your main phase, with something to play")
        self.assertEqual(stop(decision("MAIN2", active=0), "mine", origin), "")
        self.assertEqual(stop(decision("DECLARE_BLOCKERS", active=0, respond=True, casts=bolt, attacking=True), "mine",
                                       origin), "your declare blockers; you hold Disenchant (castable)")
        # ... but not while the seat's own trigger is on top (it stopped twice in that step)
        self.assertEqual(stop(decision("DECLARE_BLOCKERS", active=0, respond=True, casts=bolt, attacking=True,
                                       stack=[{"name": "Mtenda Herder", "controller": 0}]), "mine", origin), "")
        self.assertEqual(stop(decision("END", abilities=sorcerer, stack=[{"name": "Shock", "controller": 0}]), "mine",
                              origin), "")
        # mine-strict: nothing on the opponent's account, the own main phase still
        self.assertEqual(stop(decision("MAIN1", respond=True, stack=[terror], casts=bolt), "mine-strict", origin), "")
        self.assertEqual(stop(decision("END", abilities=sorcerer), "mine-strict", origin), "")
        self.assertEqual(stop(decision("MAIN1", active=0, casts=bolt), "mine-strict", origin),
                         "your main phase, with something to play")
        for until in ("mine", "mine-strict"):
            self.assertEqual(stop(decision("DECLARE_BLOCKERS", mode="block"), until, origin), "decision: block")
            self.assertEqual(stop(decision("END", mode="damage"), until, origin), "decision: damage")
            self.assertEqual(stop(decision("END", mode="choice"), until, origin), "decision: choice")

    def test_compact_view_is_a_readable_board(self):
        options = {"mode": "priority", "pass": {"op": "pass"}, "respond": True,
                   "play": {"lands": [{"card": "c8", "name": "Plains"}]},
                   "prepare": {"casts": [{"card": "c2", "name": "Swords to Plowshares", "index": 0, "x": False,
                                          "modes": []}],
                               "abilities": [{"card": "c4", "name": "Knight of Valor", "index": 1, "cost": "{1}{W}",
                                              "label": "first strike until end of turn"}]},
                   "mana": {"sources": [{"card": "c1"}]}, "special": {"specials": []}}
        decision = {"n": 12, "seat": 0, "mode": "priority", "turn": 4, "step": "MAIN1", "options": options,
                    "view": self.PHASING_VIEW}
        text = mcp.compact_view(decision)
        self.assertEqual(text, mcp.compact_view(json.loads(json.dumps(decision))), "deterministic")
        lines = text.splitlines()
        self.assertEqual(lines[0], "TURN 4 MAIN1 — your turn | you are seat 0 | decision #12: priority")
        self.assertIn("YOU (seat 0, Knights): life 18 | hand 2 | library 41 | graveyard 1 | mana pool W1", lines)
        self.assertIn("  lands: Plains c1 (tapped)", lines)
        self.assertIn("  Knight of Valor c4 2/2 [attacking; damage 1; +1/+1 x1]", lines)
        self.assertIn("  Holy Strength c14 [on Knight of Valor c4]", lines)
        self.assertIn("  Grizzly Bears c5 2/2 [tapped; PHASED OUT, returns at your next untap step]", lines)
        self.assertIn("  Serra Angel c13 4/4 [PHASED OUT, held by Oubliette (c9): phases in when it leaves the battlefield]",
                      lines)
        self.assertIn("OPPONENT (seat 1, Phasing): life 20 | hand 5 | library 40 | graveyard 0", lines)
        self.assertIn("  Swords to Plowshares c2 {W} — CASTABLE", lines)
        self.assertIn("  Plains c8 — land, playable now", lines)
        self.assertIn("  1. Lightning Bolt (opponent's) — Spell -> Knight of Valor — yours", lines)
        self.assertIn("  play a land: Plains c8 (referee_play_land)", lines)
        self.assertIn("  cast: Swords to Plowshares c2 {W} (referee_cast)", lines)
        self.assertIn("  activate: Knight of Valor c4 #1 {1}{W} — first strike until end of turn (referee_cast kind=ability)",
                      lines)
        self.assertEqual(lines[-2:], ["JOURNAL (1 new):", "  Wizard casts Lightning Bolt"])
        salve = dict(decision, options=dict(options, prepare={"abilities": [], "casts": [
            {"card": "c7", "name": "Fireblast", "index": 0, "modes": ["Pay {4}{R}{R}", "Sacrifice two Mountains"],
             "usable_modes": [1]}]}))
        self.assertIn("  cast: Fireblast c7 modes: 0=Pay {4}{R}{R} (not now) / 1=Sacrifice two Mountains (referee_cast)",
                      mcp.compact_view(salve).splitlines())
        banner = dict(decision, options=dict(options, prepare={"casts": [], "abilities": [
            {"card": "c7", "name": "Jabari's Banner", "index": 0, "cost": "{1}",
             "label": "{1}, {T}: Target creature gains flanking until end of turn."}]}))
        self.assertIn("  activate: Jabari's Banner c7 #0 — {1}, {T}: Target creature gains flanking until end of turn. "
                      "(referee_cast kind=ability)", mcp.compact_view(banner).splitlines())
        # an announcement: every slot, every token and the card it stands for
        announcing = dict(decision, options={"mode": "priority", "announcement": {
            "name": "Swords to Plowshares", "kind": "spell", "x": 0,
            "slots": [{"label": "target creature", "min": 1, "max": 1, "divided": 0,
                       "targets": [{"id": "t0", "label": "Knight of Valor — yours"}]}]},
            "draft": {"card": "c2", "reachable": True}},
            view=dict(self.PHASING_VIEW, presentation=dict(self.PHASING_VIEW["presentation"],
                                                           targets=[{"token": "t0", "ref": {"kind": "card", "id": "c4", "amount": 0}}])))
        text = mcp.compact_view(announcing)
        self.assertIn("ANNOUNCING Swords to Plowshares (spell) — the cost can be paid now", text)
        self.assertIn("  slot 0: target creature (choose 1-1): t0 Knight of Valor — yours [c4]", text)
        self.assertIn('{"op":"submit","targets":[[token, amount], ...]}', text)
        # a choice and a block decision
        choosing = {"n": 3, "seat": 1, "mode": "choice", "options": {"mode": "choice", "cancel": {"op": "cancel"}},
                    "view": {"turn": 2, "step": "UPKEEP", "active": 1, "players": [], "hand": [],
                             "choice": {"prompt": "Choose a color", "source": "Fellwar Stone", "options": ["White", "Red"],
                                        "count": 1, "cancel": True}}}
        text = mcp.compact_view(choosing)
        self.assertIn("CHOICE (Fellwar Stone): Choose a color — pick 1 (cancel allowed)", text)
        self.assertIn("  1: Red", text)
        blocking = {"n": 4, "seat": 0, "mode": "block", "view": {"turn": 2, "step": "DECLARE_BLOCKERS", "active": 1},
                    "options": {"mode": "block", "block": {"blockable": [
                        {"blocker": "c3", "name": "Wall of Swords", "attackers": [{"card": "c9", "name": "Grizzly Bears"}]}]}}}
        self.assertIn("  Wall of Swords c3 can block: Grizzly Bears c9", mcp.compact_view(blocking))
        # a rules hint: reminder text dropped, one line, cut short
        self.assertEqual(mcp._rules_hint({"rules": "Flying\nPhasing (This phases in or out before you untap.)"}),
                         "Flying; Phasing")
        long = mcp._rules_hint({"rules": "x" * 200})
        self.assertEqual(len(long), mcp.RULES_HINT)
        self.assertTrue(long.endswith("…"))
        angel = dict(self.PHASING_VIEW["players"][1]["phased_out"][1], rules="Flying, vigilance")
        self.assertTrue(mcp._permanent(angel, {}, 0, {}, {}, {}, 1, phased=True).endswith(" — Flying, vigilance"))

    def test_targets_are_named_by_what_they_are(self):
        view = {"players": [{"seat": 0, "battlefield": [{"id": "c4", "name": "Knight of Valor", "controller": 0}]},
                            {"seat": 1, "battlefield": [{"id": "c9", "name": "Grizzly Bears", "controller": 1},
                                                        {"id": "c10", "name": "Grizzly Bears", "controller": 1}]}],
                "presentation": {"targets": [{"token": "t0", "ref": {"kind": "player", "id": "0"}},
                                             {"token": "t1", "ref": {"kind": "player", "id": "1"}},
                                             {"token": "t2", "ref": {"kind": "card", "id": "c9"}},
                                             {"token": "t3", "ref": {"kind": "card", "id": "c10"}},
                                             {"token": "t4", "ref": {"kind": "card", "id": "c4"}}]}}
        rows = [{"id": "t0", "label": "You"}, {"id": "t1", "label": "Opponent"},
                {"id": "t2", "label": "Grizzly Bears — opponent's"}, {"id": "t3", "label": "Grizzly Bears — opponent's"},
                {"id": "t4", "label": "Knight of Valor — yours"}]
        bolt = {"name": "Lightning Bolt", "slots": [{"label": "target creature or player", "min": 1, "max": 1,
                                                    "divided": 0, "targets": rows}]}
        place = mcp.map_targets
        self.assertEqual([p["token"] for p in place(bolt, view, 0, ["c10"])], ["t3"])
        self.assertEqual([p["token"] for p in place(bolt, view, 0, ["opponent"])], ["t1"])
        self.assertEqual([p["token"] for p in place(bolt, view, 0, ["me"])], ["t0"])
        self.assertEqual([p["token"] for p in place(bolt, view, 1, ["me"])], ["t1"], "`me` is the seat's own")
        self.assertEqual([p["token"] for p in place(bolt, view, 0, [1])], ["t1"])
        self.assertEqual([p["token"] for p in place(bolt, view, 0, ["Knight of Valor"])], ["t4"])
        self.assertEqual([p["token"] for p in place(bolt, view, 0, ["t2"])], ["t2"])
        self.assertEqual(place(bolt, view, 0, ["c9"])[0], {"slot": 0, "token": "t2", "label": "Grizzly Bears — opponent's",
                                                          "target": "c9", "amount": 0})
        with self.assertRaises(mcp.CastRefused) as caught:
            place(bolt, view, 0, ["Grizzly Bears"])
        self.assertIn("several targets are called 'Grizzly Bears'", caught.exception.message)
        self.assertEqual(len(caught.exception.more["legal"][0]["targets"]), 5)
        for wrong in (["c77"], ["Serra Angel"], ["c9", "c10"], []):
            with self.subTest(wrong=wrong), self.assertRaises(mcp.CastRefused):
                place(bolt, view, 0, wrong)
        # the referee's own `card` beside a token wins; a referee with neither falls back to the label
        tagged = {"slots": [{"min": 1, "max": 1, "targets": [{"id": "t7", "label": "Grizzly Bears — opponent's", "card": "c10"}]}]}
        self.assertEqual(place(tagged, {}, 0, ["c10"])[0]["token"], "t7")
        plain_view = {"players": view["players"]}
        old = {"slots": [{"min": 1, "max": 1, "targets": [{"id": "t0", "label": "You"}, {"id": "t5", "label": "Knight of Valor — yours"},
                                                          {"id": "t6", "label": "Grizzly Bears — opponent's"},
                                                          {"id": "t8", "label": "Grizzly Bears — opponent's"}]}]}
        self.assertEqual(place(old, plain_view, 0, ["c4"])[0]["token"], "t5")
        self.assertEqual(place(old, plain_view, 0, ["you"])[0]["token"], "t0")
        with self.assertRaises(mcp.CastRefused):
            place(old, plain_view, 0, ["c9"])   # two tokens read alike and nothing says which is c9
        # divided amounts: one target takes all; several share; amounts must add up
        fireball = {"name": "Fireball", "slots": [{"label": "any", "min": 1, "max": 5, "divided": 5, "targets": rows}]}
        self.assertEqual([p["amount"] for p in place(fireball, view, 0, ["c9"])], [5])
        self.assertEqual([p["amount"] for p in place(fireball, view, 0, ["c9", "c10"])], [3, 2])
        self.assertEqual([p["amount"] for p in place(fireball, view, 0, [["c9", 1], {"target": "opponent", "amount": 4}])], [1, 4])
        with self.assertRaises(mcp.CastRefused):
            place(fireball, view, 0, [["c9", 1], ["c10", 1]])
        # two slots, filled in order; a slot named explicitly
        two = {"name": "Two", "slots": [{"label": "target creature", "min": 1, "max": 1, "divided": 0, "targets": rows[2:]},
                                        {"label": "target player", "min": 1, "max": 1, "divided": 0, "targets": rows[:2]}]}
        self.assertEqual([(p["slot"], p["token"]) for p in place(two, view, 0, ["c9", "opponent"])], [(0, "t2"), (1, "t1")])
        self.assertEqual([(p["slot"], p["token"]) for p in place(two, view, 0, [{"target": "me", "slot": 1}, "c4"])],
                         [(0, "t4"), (1, "t0")])
        with self.assertRaises(mcp.CastRefused):
            place(two, view, 0, ["opponent"])   # the creature slot comes first and needs one

    def test_a_count_an_earlier_target_sets_narrows_the_slot(self):
        """PROTOCOL 28 (Pack 9 — Reap): a slot whose count an earlier target
        sets carries `counts`, [earlier token, min, max] per candidate; its
        own min/max are the widest. The placement and the decision menu
        both narrow it to the earlier pick (usable only)."""
        view = {"players": [{"seat": 0, "graveyard": [{"id": "c1", "name": "Grizzly Bears", "controller": 0},
                                                      {"id": "c2", "name": "Hill Giant", "controller": 0},
                                                      {"id": "c3", "name": "Llanowar Elves", "controller": 0}]},
                            {"seat": 1}],
                "presentation": {"targets": [{"token": "t0", "ref": {"kind": "player", "id": "1"}},
                                             {"token": "t1", "ref": {"kind": "card", "id": "c1"}},
                                             {"token": "t2", "ref": {"kind": "card", "id": "c2"}},
                                             {"token": "t3", "ref": {"kind": "card", "id": "c3"}}]}}
        cards = [{"id": "t1", "label": "Grizzly Bears — yours"}, {"id": "t2", "label": "Hill Giant — yours"},
                 {"id": "t3", "label": "Llanowar Elves — yours"}]
        reap = {"name": "Reap", "slots": [
            {"label": "target opponent", "min": 1, "max": 1, "divided": 0, "targets": [{"id": "t0", "label": "Opponent"}],
             "counts": []},
            {"label": "target card", "min": 0, "max": 2, "divided": 0, "targets": cards, "counts": [["t0", 0, 1]]}]}
        self.assertEqual(mcp.slot_span(reap["slots"][1], {"t0"}), (0, 1), "the opponent picked: one card")
        self.assertEqual(mcp.slot_span(reap["slots"][1], set()), (0, 2), "nothing picked yet: the widest")
        self.assertEqual(mcp.slot_span({"min": 1, "max": 1}, {"t0"}), (1, 1), "an ordinary slot is its own")
        # a trigger is a "spell or ability" target (Silver Wyvern), named by its card
        wyvern = {"name": "Wyvern", "slots": [{"label": "target spell or ability", "min": 1, "max": 1, "divided": 0,
                                               "targets": [{"id": "t5", "label": "Triggered ability: Test Herald"}]}]}
        self.assertEqual([p["token"] for p in mcp.map_targets(wyvern, {}, 0, ["Test Herald"])], ["t5"])
        place = mcp.map_targets
        self.assertEqual([p["token"] for p in place(reap, view, 0, ["opponent", "c1"])], ["t0", "t1"])
        with self.assertRaises(mcp.CastRefused) as caught:
            place(reap, view, 0, ["opponent", "c1", "c2"])
        self.assertIn("more targets than the spell takes", caught.exception.message)
        dm = mcp.decision_menu
        decision = {"n": 1, "seat": 0, "view": view, "options": {"mode": "priority", "announcement": reap,
                                                                 "draft": {"card": "c9"}}}
        sub = {"kind": "targets", "slot": 1, "picked": [{"token": "t0", "slot": 0, "id": "opp"}],
               "slots": reap["slots"], "name": "Reap"}
        items = dm.target_items(decision, sub)
        picks = [i for i in items if i["id"].startswith("target:c")]
        self.assertEqual(len(picks), 3, "each card may be the one")
        for item in picks:
            final = item["plan"].get("final")
            self.assertIsNotNone(final, "one card fills the slot: the pick casts it")
        one = {**sub, "picked": sub["picked"] + [{"token": "t1", "slot": 1, "id": "c1"}]}
        items = dm.target_items(decision, one)
        self.assertEqual([i["id"] for i in items if i["id"].startswith("target:c")], [],
                         "a second card is never offered past the count")

    def test_actions_are_completed_with_the_wire_defaults(self):
        decision = {"options": {"play": {"lands": [{"card": "c8", "name": "Plains"}]},
                                "prepare": {"casts": [{"card": "c2", "name": "Lightning Bolt"}],
                                            "abilities": [{"card": "c4", "name": "Knight of Valor", "index": 1}]}}}
        done = mcp.complete_action
        self.assertEqual(done({"op": "autoprepare", "card": "c2"}, decision),
                         {"op": "autoprepare", "card": "c2", "kind": "spell", "index": 0, "mode": 0, "excluded": [], "count": 1})
        self.assertEqual(done({"op": "prepare", "card": "lightning bolt"}, decision),
                         {"op": "prepare", "card": "c2", "kind": "spell", "index": 0, "x": 0, "mode": 0})
        self.assertEqual(done({"op": "prepare", "card": "Knight of Valor", "kind": "ability", "index": 1}, decision)["card"], "c4")
        self.assertEqual(done({"op": "play", "card": "Plains"}, decision), {"op": "play", "card": "c8"})
        self.assertEqual(done({"op": "play", "card": "Island"}, decision), {"op": "play", "card": "Island"})
        self.assertEqual(done({"op": "autopay"}, None), {"op": "autopay", "excluded": [], "count": 1})
        self.assertEqual(done({"op": "submit"}, None), {"op": "submit", "targets": []})
        self.assertEqual(done({"op": "pass"}, decision), {"op": "pass"})
        self.assertEqual(done({"op": "prepare", "card": "c2", "x": 3}, decision)["x"], 3, "a given key is kept")


class PinTest(unittest.TestCase):
    """The door, the release and the pages know the verb."""

    def test_door_dispatches_mcp(self):
        door = (ROOT / "shandalar.sh").read_text(encoding="utf-8")
        self.assertIn('mcp) exec python3 tools/shandalar_mcp.py "$@" ;;', door)
        self.assertRegex(door, r"(?m)^#\s+\./shandalar\.sh mcp\s.*MCP server", "the door's listing names the verb")
        build = (ROOT / "build_release.sh").read_text(encoding="utf-8")
        self.assertIn('mcp) exec python3 tools/shandalar_mcp.py "$@" ;;', build)
        sys.path.insert(0, str(TOOLS_DIR))
        import package_release as pack  # noqa: E402
        self.assertIn("shandalar_mcp.py", pack.TOOLS)
        self.assertIn('mcp) exec python3 tools/shandalar_mcp.py "$@" ;;', pack.DISPATCHER)

    def test_pages_name_the_server(self):
        contract = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
        self.assertIn("## The MCP server", contract)
        self.assertIn("shandalar.sh mcp", contract)
        for tool in ("referee_start", "referee_act", "write_deck", "check_deck", "lab", "autodeck", "lab_next"):
            self.assertIn("`%s`" % tool, contract, tool)
        code_map = (ROOT / "docs" / "CODE_MAP.md").read_text(encoding="utf-8")
        for name in ("shandalar_mcp.py", "test_shandalar_mcp.py", "test_mcp_2026_09_27.gd"):
            self.assertIn(name, code_map, name)
        readme = (ROOT / "DeckLab" / "README.md").read_text(encoding="utf-8")
        self.assertIn("shandalar_mcp.py", readme)

    def test_catalogue_from_the_command_line(self):
        done = subprocess.run([sys.executable, str(SERVER), "--door", str(ROOT / "shandalar.sh"), "--catalogue"],
                              capture_output=True, text=True, cwd=str(ROOT), timeout=60)
        self.assertEqual(done.returncode, 0, done.stderr)
        listing = json.loads(done.stdout)
        self.assertIn("referee_start", [t["name"] for t in listing["tools"]])
        # The catalogue is for anyone's client: no home path, no login,
        # nothing of this machine (package_release's own guard, on text).
        login = Path.home().name
        for word in (str(Path.home()), f"/home/{login}/", f"/Users/{login}/", "/home/"):
            self.assertNotIn(word.lower(), done.stdout.lower(), word)


@unittest.skipUnless(LIVE, "SHANDALAR_MCP_LIVE=1 runs the real door")
class LiveTest(unittest.TestCase):
    """The real door, the real engine: a deck written and checked, a
    duel played to its end through the pilot, the Lab's plan."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="shandalar-mcp-live-")
        cls.workspace = ROOT / "workspace" / ("live_%d" % os.getpid())
        cls.client = Client(ROOT / "shandalar.sh", cls.workspace)
        cls.init = cls.client.ask("initialize", {"protocolVersion": "2025-06-18"}, timeout=120)
        cls.client.notify("notifications/initialized")

    @classmethod
    def tearDownClass(cls):
        cls.client.close()
        import shutil
        shutil.rmtree(cls.workspace, ignore_errors=True)
        cls.tmp.cleanup()

    def test_version_and_status(self):
        version = self.init["result"]["serverInfo"]["version"]
        self.assertRegex(version, r"^\d+\.\d+\.\d+")
        status = self.client.payload("status", timeout=120)
        self.assertEqual(status["version"], version)
        self.assertEqual(status["root"], str(ROOT))
        full = self.client.payload("play_guide")["text"]
        self.assertEqual(full, (ROOT / "agentic-playgude-mtg.md").read_text(encoding="utf-8"))
        for chapter in range(1, 17):
            page = self.client.payload("play_guide", {"chapter": chapter})["text"]
            self.assertTrue(page.startswith(f"## {chapter}. "))
            self.assertEqual(len(re.findall(r"^## \d+\. ", page, re.MULTILINE)), 1)
        self.assertIn("Deck-building strategy", page)

    def test_packs_cards_check(self):
        listed = self.client.payload("list_decks", {"folder": "decks"})
        self.assertGreaterEqual(listed["count"], 330)
        page = self.client.payload("list_decks", {"folder": "decks/tournament", "search": "ec2015_beckert", "limit": 1})
        self.assertEqual(page["count"], 1)
        chosen = page["decks"][0]["file"]
        deck = self.client.payload("read_deck", {"deck": chosen})
        self.assertEqual(deck["cards"], 60)
        self.assertEqual(deck["errors"], [])
        packs = self.client.payload("packs", timeout=180)
        self.assertIn("pack-1", packs["known"])
        cards = self.client.payload("cards", {"names": ["Lightning Bolt", "Lightnin Bolt"]}, timeout=180)
        self.assertTrue(cards["cards"][0]["known"])
        self.assertEqual(cards["cards"][1]["near"], ["Lightning Bolt"])
        check = self.client.payload("check_deck", {"decks": [chosen]}, timeout=180)
        self.assertTrue(check["playable"])
        self.assertEqual(check["decks"][0]["cards"], 60)
        refused = self.client.call("check_deck", {"decks": ["missing.deck"]}, timeout=180)
        self.assertTrue(refused["isError"])
        self.assertEqual(refused["structuredContent"]["error"]["tool"], "lab_query")

    def test_write_deck_is_checked_by_the_engine(self):
        written = self.client.payload("write_deck", {"file": "burn.deck", "name": "Burn",
                                                     "cards": ["4 Lightning Bolt", "4 Bogus Card", "20 Mountain"]}, timeout=180)
        self.assertFalse(written["playable"])
        self.assertEqual(written["check"]["decks"][0]["unknown"][0]["name"], "Bogus Card")
        listed = self.client.payload("list_decks", {"folder": str(self.workspace)})
        self.assertEqual(listed["decks"][0]["name"], "Burn")
        # the word names the workspace wherever it lives, a relative folder is tried there too
        self.assertEqual(self.client.payload("list_decks", {"folder": "workspace"})["decks"][0]["name"], "Burn")
        (self.workspace / "mine").mkdir()
        (self.workspace / "mine" / "red.deck").write_text("// NAME: Red\n20 Mountain\n", encoding="utf-8")
        self.assertEqual([r["name"] for r in self.client.payload("list_decks", {"folder": "mine"})["decks"]], ["Red"])
        missing = self.client.call("list_decks", {"folder": "nowhere"})
        self.assertTrue(missing["isError"])
        self.assertIn("not a folder", missing["structuredContent"]["error"]["message"])

    def test_lab_and_autodeck_plan(self):
        plan = self.client.payload("lab", {"deck_a": "big_green.deck", "deck_b": "white_knights.deck",
                                           "games": 4, "dry_run": True}, timeout=180)
        self.assertIn("plan", plan)
        self.assertIn("--no-elo", plan["argv"])
        field = self.client.payload("autodeck", {"out": "ws_field", "count": 2, "dry_run": True}, timeout=180)
        self.assertIn("plan", field)
        manual = self.client.payload("manual", {"verb": "lab"}, timeout=120)
        self.assertIn("--deck-a", manual["text"])

    def test_a_small_lab_run_reads_back_and_resume_is_heard(self):
        # 2026-10-03, against the real Lab: a run without `out` lands in the
        # workspace and comes back with run/results/next; progress is
        # reported when asked; `lab_resume` reaches the Lab's own resume
        # check (kind "resume") instead of being refused as an option.
        ident = self.client.next_id
        self.client.next_id += 1
        self.client.raw(json.dumps({"jsonrpc": "2.0", "id": ident, "method": "tools/call", "params": {
            "name": "lab", "_meta": {"progressToken": 7},
            "arguments": {"deck_a": "big_green.deck", "deck_b": "white_knights.deck", "games": 2,
                          "procs": 1, "timeout": 300}}}))
        notes = []
        while True:
            message = json.loads(self.client.line(300))
            if message.get("method") == "notifications/progress":
                notes.append(message["params"])
                continue
            self.assertEqual(message.get("id"), ident, message)
            break
        result = message["result"]
        self.assertFalse(result["isError"], result)
        run = result["structuredContent"]
        self.assertEqual(run["run"]["tool"], "deck_lab")
        self.assertIn("matchups", run["results"])
        self.assertTrue(run["out"].startswith("workspace/"), run["out"])
        self.assertTrue(notes, "the finished heartbeat at least")
        self.assertEqual(notes[-1]["progress"], 2)
        self.assertEqual(notes[-1]["total"], 2)
        empty = self.workspace / "not_a_run"
        empty.mkdir(parents=True, exist_ok=True)
        refused = self.client.call("lab_resume", {"out": str(empty)}, timeout=180)
        self.assertTrue(refused["isError"])
        self.assertEqual(refused["structuredContent"]["error"]["kind"], "resume")

    def test_duel_to_the_end(self):
        opened = self.client.payload("referee_start", {"deck_a": "decks/tournament/ec2015_beckert.deck",
                                                       "deck_b": "white_knights.deck",
                                                       "seed": 7, "timeout": 180}, timeout=240)
        game = opened["game"]
        self.assertEqual(opened["hello"]["seed"], 7)
        self.assertEqual(opened["decision"]["mode"], "opening")
        self.assertEqual(len(opened["decision"]["brief"]["players"]), 2)
        self.assertLess(len(json.dumps(opened["decision"])), 6000, "the brief view is small")
        kept = self.client.payload("referee_act", {"game": game, "action": {"op": "keep"}, "timeout": 180}, timeout=240)
        self.assertIn("decision", kept)
        wrong = self.client.payload("referee_act", {"game": game, "action": {"op": "attack", "cards": []}, "timeout": 180}, timeout=240)
        self.assertTrue(wrong.get("refused"))
        played = self.client.payload("referee_autoplay", {"game": game, "timeout": 180}, timeout=600)
        self.assertIn("result", played, played)
        self.assertEqual(played["result"]["reason"], "concluded", json.dumps(played.get("refused"))[:2000])
        self.assertIn(played["result"]["winner"], (0, 1))
        self.assertGreater(played["played"], 20)
        status = self.client.payload("status")
        self.assertFalse([g for g in status["games"] if g["game"] == game][0]["running"])

    def test_a_kept_duel_is_taken_up_by_another_server_and_passed_until(self):
        # one server starts the kept duel and goes away; the class's server takes it up
        first = Client(ROOT / "shandalar.sh", self.workspace)
        first.ask("initialize", {"protocolVersion": "2025-06-18"}, timeout=120)
        opened = first.payload("referee_start", {"deck_a": "decks/tournament/ec2015_beckert.deck",
                                                 "deck_b": "white_knights.deck", "seed": 11, "keep": True,
                                                 "view": "delta", "timeout": 180}, timeout=240)
        game = opened["game"]
        self.assertEqual(opened["decision"]["mode"], "opening")
        self.assertTrue(opened["decision"]["delta"]["baseline"])
        handshake = json.loads((self.workspace / "games" / (game + ".keep.json")).read_text(encoding="utf-8"))
        self.assertEqual(handshake["version"], self.init["result"]["serverInfo"]["version"])
        # the pilot keeps; the server passes priority to the first main phase with something to play
        main = first.payload("referee_act", {"game": game, "action": "default", "until": "play", "timeout": 180}, timeout=240)
        self.assertIn("stop", main, main)
        self.assertIn("decision", main, main)
        self.assertEqual(main["until"], "play")
        delta = main["decision"]["delta"]
        self.assertNotIn("baseline", delta)
        self.assertIsInstance(delta["journal"], list)
        decisions_before = main["decisions"]
        first.close()
        self.assertEqual(first.proc.returncode, 0)
        # taken up: the same decision, the whole journal in front of it
        listing = self.client.payload("referee_resume", {})
        self.assertIn(game, [k["game"] for k in listing["kept"]])
        resumed = self.client.payload("referee_resume", {"game": game, "view": "brief", "timeout": 60}, timeout=120)
        self.assertTrue(resumed["resumed"], resumed)
        self.assertEqual(resumed["decision"]["n"], main["decision"]["n"])
        self.assertEqual(resumed["decisions"], decisions_before)
        self.assertGreaterEqual(len(resumed["decision"]["brief"]["journal"]), len(delta["journal"]))
        self.assertEqual(resumed["hello"]["seed"], 11)
        # passed to the end step: every stop on the way is a place a player acts
        stops = []
        state = resumed
        for _ in range(12):
            if "result" in state or "decision" not in state:
                break
            state = self.client.payload("referee_act", {"game": game, "action": "default", "until": "end", "timeout": 180}, timeout=240)
            if "stop" in state:
                stops.append(state["stop"])
        self.assertTrue(stops, state)
        for stop in stops:
            self.assertTrue(stop.startswith(("decision: ", "the end step", "the next turn began", "a cast is in progress",
                                             "the opponent's ", "their ", "your ", "an answer was refused")), stop)
        stopped = self.client.payload("referee_stop", {"game": game}, timeout=120)
        self.assertIn("result", stopped, stopped)
        self.assertTrue(stopped["kept"])
        self.assertFalse((self.workspace / "games" / (game + ".json")).is_file())
        transcript = (self.workspace / "games" / (game + ".lines")).read_text(encoding="utf-8")
        self.assertIn('"type":"result"', transcript.replace(" ", ""))
        self.assertEqual(self.client.payload("referee_resume", {})["kept"], [])

    def test_a_duel_through_the_compact_view_the_smart_pass_and_one_call_casts(self):
        # 0.50.13, against the real engine: what the 2026-10-04 play-through
        # asked for — the board as text (`compact`), the pass to the seat's
        # next real decision (`until: "mine"`), lands and spells in one call
        # each, a refused target that leaves nothing announced and nothing
        # tapped, and the cast retried with a target from the legal list.
        opened = self.client.call("referee_start", {"deck_a": "white_knights.deck", "deck_b": "big_green.deck",
                                                    "seed": 3, "turns": 12, "view": "compact",
                                                    "rules": "modern_mana_burn", "timeout": 180},
                                  timeout=240)
        self.assertFalse(opened["isError"], opened)
        state = opened["structuredContent"]
        self.assertEqual(state["hello"]["rules"], "modern_mana_burn", "the preset reached the referee")
        game = state["game"]
        text = opened["content"][0]["text"]
        self.assertTrue(text.startswith("game %s | decisions 1 | refusals 0\nTURN " % game), text[:200])
        for part in ("YOUR HAND (7):", "OPTIONS:", '  keep: {"op":"keep"}', "OPPONENT (seat 1, "):
            self.assertIn(part, text)
        self.assertIn("brief", state["decision"])
        lands = casts = target_refusals = 0
        stops = []
        for _ in range(80):
            if "result" in state or "decision" not in state:
                break
            decision = state["decision"]
            options = decision.get("options") or {}
            brief = decision["brief"]
            mode = decision["mode"]
            base = {"game": game, "until": "mine", "timeout": 180}
            if mode == "opening":
                answer = self.client.call("referee_act", {**base, "action": {"op": "keep"}}, timeout=240)
            elif mode == "priority" and (options.get("play") or {}).get("lands") and brief["active"] == brief["seat"]:
                answer = self.client.call("referee_play_land", base, timeout=240)
                self.assertFalse(answer["isError"], answer)
                self.assertEqual(answer["structuredContent"]["action"]["op"], "play")
                lands += 1
            elif mode == "priority" and (options.get("prepare") or {}).get("casts"):
                spell = options["prepare"]["casts"][0]
                ask = {**base, "card": spell["name"]}
                if spell.get("x"):
                    ask["x"] = spell.get("budget", 0)
                if spell.get("modes"):
                    ask["mode"] = 0
                answer = self.client.call("referee_cast", ask, timeout=240)
                error = answer["structuredContent"].get("error") if answer["isError"] else None
                if error is not None and error.get("kind") == "target":
                    # nothing announced, nothing tapped; then a legal target, mine for an Aura
                    target_refusals += 1
                    self.assertTrue(error["cast"]["withdrawn"], error)
                    self.assertEqual(error["sent"][-1]["op"], "cancel")
                    self.assertNotIn("autopay", [s["op"] for s in error["sent"]])
                    self.assertNotIn("announcement", error["decision"]["options"])
                    mine = {c["id"] for p in brief["players"] if p["seat"] == brief["seat"] for c in p["battlefield"]}
                    picks = []
                    for slot in error["legal"]:
                        rows = slot["targets"]
                        own = [r for r in rows if r.get("card") in mine]
                        aura = "creature" in slot["label"].lower() and not spell["name"].startswith("Swords")
                        rows = (own if aura and own else [r for r in rows if r.get("card") not in mine] or rows)
                        picks += [r.get("card") or r["token"] for r in rows[:max(1, slot["min"])]]
                    answer = self.client.call("referee_cast", {**ask, "targets": picks}, timeout=240)
                if not answer["isError"] and answer["structuredContent"]["cast"]["result"] == "cast":
                    casts += 1
                    self.assertEqual([s["op"] for s in answer["structuredContent"]["sent"]][-1], "submit")
                elif answer["isError"]:
                    error = answer["structuredContent"]["error"]
                    self.assertTrue(error["cast"].get("withdrawn"), error)
                    self.assertNotIn("announcement", error["decision"]["options"])
                    state = {"game": game, "decision": error["decision"]}
                    # (the spell is refused again next time: pass instead)
                    answer = self.client.call("referee_act", {**base, "action": {"op": "pass"}}, timeout=240)
            elif mode == "attack":
                attackers = [a["card"] for a in (options.get("attack") or {}).get("attackable", [])]
                answer = self.client.call("referee_act", {**base, "action": {"op": "attack", "cards": attackers}},
                                          timeout=240)
            elif mode == "block":
                answer = self.client.call("referee_act", {**base, "action": {"op": "block", "pairs": []}}, timeout=240)
            else:
                answer = self.client.call("referee_act", {**base, "action": "default"}, timeout=240)
            self.assertFalse(answer["isError"], answer)
            state = answer["structuredContent"]
            text = answer["content"][0]["text"]
            self.assertTrue(text.startswith("game %s | " % game), text[:200])
            if "stop" in state:
                stops.append(state["stop"])
                if "decision" in state:
                    self.assertIn(state["decision"]["compact"], text)
        self.assertGreater(lands, 0)
        self.assertGreater(casts, 0, stops)
        self.assertGreater(target_refusals, 0, "a targeted spell was first sent without targets")
        self.assertTrue(stops)
        for stop in stops:
            self.assertTrue(stop.startswith(("decision: ", "your main phase, with something to play", "their ", "your ",
                                             "an answer was refused")), stop)
            if stop.startswith("their ") or (stop.startswith("your ") and not stop.startswith("your main")):
                self.assertIn("; you hold ", stop, "the smart pass stops on their account only while holding")
        self.client.payload("referee_stop", {"game": game}, timeout=120)

    def test_a_duel_through_the_decision_menu(self):
        # 0.50.13, against the real engine: a duel to its end through
        # `referee_pick` alone — a seeded random menu index each time, the
        # smart pass after each pick — with no refusal on the way, and the
        # compact text carrying the numbered menu.
        import random
        chooser = random.Random(5)
        opened = self.client.payload("referee_start", {"deck_a": "white_knights.deck", "deck_b": "big_green.deck",
                                                       "seed": 9, "turns": 14, "timeout": 180}, timeout=240)
        game = opened["game"]
        answer = self.client.call("referee_menu", {"game": game, "timeout": 180}, timeout=240)
        self.assertFalse(answer["isError"], answer)
        picks = 0
        while picks < 600:
            state = answer["structuredContent"]
            if "result" in state:
                break
            menu = state["menu"]
            self.assertTrue(menu, state)
            self.assertEqual(len({i["id"] for i in menu}), len(menu))
            text = answer["content"][0]["text"]
            self.assertIn("MENU (answer with referee_pick {pick: N}):", text)
            self.assertIn("  0. %s  [%s]" % (menu[0]["label"], menu[0]["id"]), text)
            answer = self.client.call("referee_pick", {"game": game, "pick": chooser.randrange(len(menu)),
                                                       "until": "mine", "timeout": 180}, timeout=240)
            self.assertFalse(answer["isError"], answer)
            self.assertNotIn("refused", answer["structuredContent"], answer["structuredContent"].get("refused"))
            picks += 1
        state = answer["structuredContent"]
        self.assertIn("result", state, "the duel ended within %d picks" % picks)
        self.assertIn(state["result"]["reason"], ("concluded", "limit"), state["result"])
        self.assertEqual(state["stats"]["refusals"], 0, state["stats"])
        self.assertGreater(picks, 10)
        self.assertIn("RESULT: ", answer["content"][0]["text"])
        self.assertTrue(answer["content"][0]["text"].endswith("rich: true` adds each item's kind, info and ops.)"))
        row = [g for g in self.client.payload("status")["games"] if g["game"] == game][0]
        self.assertFalse(row["running"])

    def test_a_hosted_table_is_joined_by_a_guest_and_played(self):
        # the server hosts a table in the game's own lobby and sits at it
        # with a second referee as the guest; the two seats are played
        # turn about with short waits (the server answers one call at a
        # time, and each seat's next decision waits on the other's answer)
        hosted = self.client.payload("referee_host", {"table": "Kitchen", "deck": "big_green.deck",
                                                      "address": "127.0.0.1", "port": 0, "turns": 12,
                                                      "timeout": 60}, timeout=120)
        host = hosted["game"]
        self.assertTrue(hosted.get("pending"), hosted)
        self.assertIsNone(hosted["hello"])
        table = hosted["table"]
        self.assertEqual((table["name"], table["access"], table["address"], table["host"], table["id"]),
                         ("Kitchen", "open", "127.0.0.1", "Agent", "r1"))
        self.assertGreater(table["port"], 0)
        self.assertTrue(table["invitation"].startswith("sglan1:"), table["invitation"])
        self.assertIn("Game Browser", hosted["note"])
        self.assertEqual([g for g in self.client.payload("status")["games"] if g["game"] == host][0]["hosted"], table)
        guest = self.client.payload("referee_join", {"invitation": table["invitation"], "deck": "white_knights.deck",
                                                     "name": "Owner", "turns": 12, "wait": 60, "timeout": 10}, timeout=60)
        other = guest["game"]
        self.assertNotEqual(other, host)
        results: dict = {}
        hellos: dict = {}
        deadline = time.time() + 420
        for _ in range(4000):
            if len(results) == 2 or time.time() > deadline:
                break
            for game in (host, other):
                if game in results:
                    continue
                state = self.client.payload("referee_wait", {"game": game, "timeout": 0.25}, timeout=60)
                if state.get("hello"):
                    hellos[game] = state["hello"]
                if "decision" in state and "result" not in state:
                    state = self.client.payload("referee_autoplay", {"game": game, "decisions": 50, "timeout": 0.25}, timeout=60)
                if "result" in state or "error" in state:
                    results[game] = state.get("result") or state["error"]
        for game in (host, other):
            if game not in results:
                # (a seat left playing would wait for its answer until idle)
                self.client.payload("referee_stop", {"game": game}, timeout=60)
        self.assertEqual(sorted(results), sorted([host, other]), results)
        for game in (host, other):
            self.assertEqual(results[game].get("type"), "result", results[game])
        self.assertEqual(hellos[host]["table"], {"id": "r1", "name": "Kitchen", "seat": 0, "hosted": True})
        self.assertEqual(hellos[other]["table"]["name"], "Kitchen")
        self.assertFalse(hellos[other]["table"]["hosted"])
        self.assertEqual(hellos[other]["table"]["seat"], 1)
        self.assertEqual(hellos[host]["seats"][0]["player"], "agent")
        self.assertEqual(hellos[host]["seats"][1]["player"], "table")
        for game, mine in ((host, 0), (other, 1)):
            result = results[game]
            self.assertIn(result["reason"], ("concluded", "limit"), result)
            self.assertEqual(result["seat"], mine)
            self.assertEqual(result["table"], {"id": "r1", "name": "Kitchen"})
            # (the lobby's own suffix on a nickname is its business)
            self.assertTrue(result["names"][0].startswith("Agent"), result["names"])
            self.assertTrue(result["names"][1].startswith("Owner"), result["names"])
        self.assertEqual(results[host]["winner"], results[other]["winner"])
        self.assertIn(results[host]["winner"], (0, 1))
        status = self.client.payload("status")
        for game in (host, other):
            self.assertFalse([g for g in status["games"] if g["game"] == game][0]["running"])
        self.assertEqual(self.client.payload("referee_resume", {})["kept"], [])


if __name__ == "__main__":
    unittest.main()
