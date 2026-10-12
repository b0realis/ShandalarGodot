#!/usr/bin/env python3
"""Self-test for the robustness campaign's fixes in the MCP server and the
decision-model door (2026-10-12, f-net): `tools/shandalar_mcp.py` and
`tools/shandalar_decide.py` under hostile input.

No Godot and no network. Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'

WHAT THIS HOLDS:

  * HALF AN EMOJI KILLS NOTHING (r4-1): a lone surrogate (`"\\ud83d"`, which
    a model writes) in a request id or an echoed argument is answered —
    escaped — and every later request is still answered. An answer that
    cannot be written at all is a -32603 for its id, never a dead worker.
  * ONE BAD LINE IS ONE PARSE ERROR (r4-2): invalid UTF-8 and JSON nested
    past Python's recursion limit are answered -32700; the server reads on.
  * A DEAD REFEREE SAYS SO (r4-3): when a pipe game's referee dies with a
    decision pending, wait/act/stop report its end — the exit code and the
    stderr tail — instead of the stale decision or "is over".
  * THE INVITATION STAYS OFF THE COMMAND LINE (r4-10): `referee_join`
    hands the referee its invitation in the environment
    (`--join env:SHANDALAR_INVITATION`), so neither `ps`, the kept game's
    record nor the summary carries the secret.
  * A MALFORMED ANSWER IS AN ERROR AND THE SAME DECISION (r4-9): the
    decision door answers an answer object of the wrong shape, an answer
    nested too deep, or half an emoji with `{"error"}` and repeats.
"""

import io
import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import shandalar_decide as decide  # noqa: E402
import shandalar_mcp as mcp  # noqa: E402

SERVER = Path(__file__).resolve().parent / "shandalar_mcp.py"
DECIDE = Path(__file__).resolve().parent / "shandalar_decide.py"


def answers(raw: bytes) -> list:
    out = []
    for line in raw.decode("utf-8").splitlines():
        if line.strip():
            out.append(json.loads(line))
    return out


def by_id(lines: list) -> dict:
    found = {}
    for message in lines:
        for one in message if isinstance(message, list) else [message]:
            found[json.dumps(one.get("id"))] = one
    return found


class Base(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="c2-f-net-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.door = self.root / "shandalar.sh"
        self.door.write_text("#!/bin/sh\nexit 3\n", encoding="utf-8")
        self.door.chmod(0o755)
        self.server = mcp.Server(self.door, self.root / "workspace")
        self.addCleanup(self.server.shutdown)

    def serve_bytes(self, data: bytes) -> list:
        """The server's own loop over `data`, written to a strict UTF-8
        stream like the real stdout."""
        raw = io.BytesIO()
        sink = io.TextIOWrapper(raw, encoding="utf-8", write_through=True)
        source = io.BytesIO(data)
        self.assertEqual(self.server.serve(source, sink), 0)
        sink.flush()
        return answers(raw.getvalue())

    def run_server(self, data: bytes, timeout: float = 60) -> subprocess.CompletedProcess:
        return subprocess.run([sys.executable, str(SERVER), "--door", str(self.door),
                               "--workspace", str(self.root / "workspace")],
                              input=data, capture_output=True, timeout=timeout, cwd=str(self.root))


# --- r4-1 -------------------------------------------------------------------

class LoneSurrogateTest(Base):
    LINES = (b'{"jsonrpc":"2.0","id":"a\\ud800","method":"no/such"}\n'
             b'{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"referee_wait",'
             b'"arguments":{"game":"g\\ud83d"}}}\n'
             b'{"jsonrpc":"2.0","id":2,"method":"tools/list"}\n'
             b'{"jsonrpc":"2.0","id":"p\\udc00","method":"ping"}\n'
             b'{"jsonrpc":"2.0","id":3,"method":"ping"}\n')

    def test_a_lone_surrogate_is_answered_and_the_worker_lives(self):
        got = by_id(self.serve_bytes(self.LINES))
        # the id comes back as sent (JSON-escaped, so the line is UTF-8)
        self.assertEqual(got[json.dumps("a\ud800")]["error"]["code"], -32601)
        self.assertEqual(got[json.dumps("p\udc00")]["result"], {})
        wait = got["1"]["result"]
        self.assertTrue(wait["isError"])
        self.assertEqual(wait["structuredContent"]["error"]["game"], "g\ud83d")
        self.assertIn("tools", got["2"]["result"])
        self.assertEqual(got["3"]["result"], {})

    def test_the_real_process_answers_every_request(self):
        done = self.run_server(self.LINES)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertNotIn(b"Traceback", done.stderr)
        got = by_id(answers(done.stdout))
        self.assertEqual(set(got), {json.dumps("a\ud800"), "1", "2", json.dumps("p\udc00"), "3"})
        for line in done.stdout.splitlines():
            line.decode("utf-8")      # every line is valid UTF-8

    def test_an_answer_that_cannot_be_written_is_a_32603_and_the_next_is_answered(self):
        class Unwritable:
            def __str__(self):
                raise RuntimeError("this answer cannot be written")

        real = self.server.handle

        def handle(message):
            if isinstance(message, dict) and message.get("id") == 1:
                return {"jsonrpc": "2.0", "id": 1, "result": {"odd": Unwritable()}}
            return real(message)

        with mock.patch.object(self.server, "handle", side_effect=handle):
            got = by_id(self.serve_bytes(b'{"jsonrpc":"2.0","id":1,"method":"tools/list"}\n'
                                         b'{"jsonrpc":"2.0","id":2,"method":"tools/list"}\n'))
        self.assertEqual(got["1"]["error"]["code"], -32603)
        self.assertIn("tools", got["2"]["result"])

    def test_non_ascii_stays_readable_on_the_wire(self):
        raw = io.BytesIO()
        sink = io.TextIOWrapper(raw, encoding="utf-8", write_through=True)
        mcp.emit(sink, {"name": "Æther Storm"})
        self.assertIn("Æther Storm".encode("utf-8"), raw.getvalue())


# --- r4-2 -------------------------------------------------------------------

class ParseErrorTest(Base):
    def test_invalid_utf8_is_a_parse_error_and_the_server_reads_on(self):
        done = self.run_server(b'\xff\xfe{"jsonrpc":"2.0","id":1,"method":"ping"}\n'
                               b'{"jsonrpc":"2.0","id":2,"method":"ping"}\n')
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertNotIn(b"Traceback", done.stderr)
        lines = answers(done.stdout)
        self.assertEqual(lines[0]["error"]["code"], -32700)
        self.assertEqual(lines[0]["id"], None)
        self.assertEqual(by_id(lines)["2"]["result"], {})

    def test_deep_nesting_is_a_parse_error_and_the_server_reads_on(self):
        nested = b"[" * 100000 + b"]" * 100000
        done = self.run_server(nested + b"\n" + b'{"jsonrpc":"2.0","id":2,"method":"ping"}\n')
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertNotIn(b"Traceback", done.stderr)
        lines = answers(done.stdout)
        self.assertEqual(lines[0]["error"]["code"], -32700)
        self.assertEqual(by_id(lines)["2"]["result"], {})

    def test_in_process_too(self):
        lines = self.serve_bytes(b"\xc3\x28\n" + b"[" * 50000 + b"\n" + b'{"jsonrpc":"2.0","id":9,"method":"ping"}\n')
        self.assertEqual([m.get("error", {}).get("code") for m in lines[:2]], [-32700, -32700])
        self.assertEqual(by_id(lines)["9"]["result"], {})


# --- r4-3 -------------------------------------------------------------------

REFEREE = (
    "import json, sys\n"
    "print('referee: about to fall over', file=sys.stderr, flush=True)\n"
    "print(json.dumps({'type':'hello','seats':[{'seat':0,'player':'agent'},{'seat':1,'player':'wizard'}],'seed':1}), flush=True)\n"
    "view = {'players': [], 'hand': [], 'stack': [], 'mode': 'priority', 'actor': 0, 'turn': 1, 'step': 'MAIN1', 'journal': []}\n"
    "print(json.dumps({'type':'decision','n':1,'seat':0,'mode':'priority','turn':1,'step':'MAIN1',"
    "'options':{'pass':{'op':'pass'}},'view':view}), flush=True)\n"
    "sys.stdin.read()\n")


class DeadRefereeTest(Base):
    def open_game(self) -> mcp.Game:
        game = mcp.Game("g1", [sys.executable, "-u", "-c", REFEREE], "options", self.root,
                        self.root / "g1.stderr")
        self.server.games[game.ident] = game
        state = game.advance(20)
        self.assertEqual(state["decision"]["n"], 1)
        return game

    def kill(self, game: mcp.Game) -> None:
        game.proc.send_signal(signal.SIGKILL if hasattr(signal, "SIGKILL") else signal.SIGTERM)
        game.proc.wait(timeout=10)
        time.sleep(0.2)

    def assert_end_reported(self, state: dict) -> None:
        self.assertNotIn("decision", state)
        self.assertNotIn("pending", state)
        error = state.get("error")
        self.assertIsInstance(error, dict, state)
        self.assertEqual(error.get("kind"), "run")
        self.assertIsNotNone(error.get("exit"))
        self.assertNotEqual(error.get("exit"), 0)
        self.assertIn("referee: about to fall over", "\n".join(error.get("stderr") or []))

    def test_wait_reports_the_end_not_the_stale_decision(self):
        game = self.open_game()
        self.kill(game)
        self.assert_end_reported(self.server.call("referee_wait", {"game": "g1", "timeout": 3}))
        self.assertFalse(game.running)

    def test_resume_of_a_live_id_reports_the_end_too(self):
        game = self.open_game()
        self.kill(game)
        self.assert_end_reported(self.server.call("referee_resume", {"game": "g1", "timeout": 3}))

    def test_act_reports_the_end_not_is_over(self):
        game = self.open_game()
        self.kill(game)
        self.assert_end_reported(self.server.call("referee_act", {"game": "g1", "action": {"op": "pass"}}))

    def test_stop_reports_the_end(self):
        game = self.open_game()
        self.kill(game)
        self.assert_end_reported(self.server.call("referee_stop", {"game": "g1"}))

    def test_a_live_game_is_not_touched(self):
        game = self.open_game()
        state = self.server.call("referee_wait", {"game": "g1", "timeout": 1})
        self.assertEqual(state["decision"]["n"], 1)
        self.assertTrue(game.running)


# --- r4-10 ------------------------------------------------------------------

RECORDING_DOOR = r'''#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
here = Path(__file__).resolve().parent
with (here / "door.log").open("a", encoding="utf-8") as log:
    log.write(json.dumps({"argv": sys.argv[1:], "invitation": os.environ.get("SHANDALAR_INVITATION")}) + "\n")
if "--listen" in sys.argv:
    time.sleep(5)
    sys.exit(0)
print(json.dumps({"type": "hello", "seats": [{"seat": 0, "player": "agent"}], "seed": 1,
                  "table": {"host": "Someone"}}), flush=True)
view = {"players": [], "hand": [], "stack": [], "mode": "priority", "actor": 0, "turn": 1, "step": "MAIN1", "journal": []}
print(json.dumps({"type": "decision", "n": 0, "seat": 0, "mode": "priority", "turn": 1, "step": "MAIN1",
                  "options": {"pass": {"op": "pass"}}, "view": view}), flush=True)
sys.stdin.read()
'''

SECRET = "sglan1:SECRET-ACCESS-0123456789abcdef"


class InvitationTest(Base):
    def setUp(self):
        super().setUp()
        self.door.write_text(RECORDING_DOOR, encoding="utf-8")
        self.door.chmod(0o755)
        (self.root / "a.deck").write_text("40 Forest\n", encoding="utf-8")

    def door_log(self) -> list:
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            path = self.root / "door.log"
            if path.is_file() and path.read_text(encoding="utf-8").strip():
                return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]
            time.sleep(0.1)
        self.fail("the door never ran")

    def test_a_pipe_join_passes_the_invitation_in_the_environment(self):
        state = self.server.call("referee_join", {"invitation": SECRET, "deck": "a.deck", "keep": False,
                                                 "timeout": 15})
        self.assertEqual(state["decision"]["n"], 0)
        record = self.door_log()[0]
        self.assertEqual(record["invitation"], SECRET)
        self.assertNotIn(SECRET, json.dumps(record["argv"]))
        self.assertEqual(record["argv"][:3], ["referee", "--join", "env:SHANDALAR_INVITATION"])
        summary = self.server.games[state["game"]].summary()
        self.assertNotIn(SECRET, json.dumps(summary))
        self.assertNotIn(SECRET, os.environ.get("SHANDALAR_INVITATION", ""))

    def test_a_kept_join_writes_no_secret_to_its_record(self):
        state = self.server.call("referee_join", {"invitation": SECRET, "deck": "a.deck", "timeout": 0.5})
        record = self.door_log()[0]
        self.assertEqual(record["invitation"], SECRET)
        self.assertNotIn(SECRET, json.dumps(record["argv"]))
        games = self.root / "workspace" / "games"
        for path in games.iterdir():
            self.assertNotIn(SECRET, path.read_text(encoding="utf-8", errors="replace"), path.name)
        self.assertNotIn(SECRET, json.dumps(self.server.games[state["game"]].summary()))
        self.assertNotIn(SECRET, json.dumps(state, default=str))


# --- r4-9 (and r4-1's twin in the decision door) -----------------------------

class Driver:
    stats = {"decisions": 0}


class StubEnv:
    def __init__(self):
        self.driver = Driver()
        self._done = False
        self.result = {"winner": 0}
        self.picks = []

    def reset(self, seed=None):
        return {"turn": 1}

    @property
    def done(self):
        return self._done

    def menu(self, rich=False):
        return [{"id": "pass", "label": "Pass"}, {"id": "keep", "label": "Keep"}]

    def step(self, pick):
        item = decide.dm.resolve_pick(self.menu(), pick)
        self.picks.append(item["id"])
        self._done = True
        return {"turn": 1}, 0.0, True, {"item": item}

    def close(self):
        pass

    def stats(self):
        return {}


class DecideTest(unittest.TestCase):
    def play(self, text: str) -> tuple[int, list, StubEnv]:
        raw = io.BytesIO()
        out = io.TextIOWrapper(raw, encoding="utf-8", write_through=True)
        env = StubEnv()
        with mock.patch.object(sys, "stdout", out):
            code = decide.interactive(env, False, source=io.StringIO(text), systemone=False)
        out.flush()
        return code, answers(raw.getvalue()), env

    def test_malformed_answers_are_errors_and_the_decision_repeats(self):
        cases = {"answers_not_object": '{"answers": "action"}',
                 "answers_list": '{"answers": ["x"]}',
                 "action_not_object": '{"answers": {"action": 3}}',
                 "probabilities_text": '{"answers": {"action": {"probabilities": {"Pass": "high"}}}}',
                 "deep_nesting": "[" * 100000 + "]" * 100000,
                 "lone_surrogate": '"\\ud83d"'}
        for name, bad in cases.items():
            with self.subTest(name=name):
                code, lines, env = self.play(bad + "\n1\n")
                self.assertEqual(code, 0)
                self.assertEqual(env.picks, ["keep"])
                errors = [line for line in lines if "error" in line]
                self.assertEqual(len(errors), 1, lines)
                self.assertLess(len(errors[0]["error"]), 400)
                menus = [line for line in lines if "menu" in line]
                self.assertEqual(len(menus), 2, "the same decision again")

    def test_a_numeric_probability_still_picks(self):
        code, _lines, env = self.play('{"answers": {"action": {"probabilities": {"Pass": 0.2, "Keep": 0.7}}}}\n')
        self.assertEqual(code, 0)
        self.assertEqual(env.picks, ["keep"])

    def test_the_real_process_survives_invalid_utf8_on_stdin(self):
        # --describe does not read stdin; the line protocol does, and a
        # byte that is not UTF-8 must not end the process with a traceback.
        done = subprocess.run([sys.executable, "-c",
                               "import sys; sys.path.insert(0, %r)\n"
                               "import shandalar_decide as d\n" % str(DECIDE.parent) +
                               "class E:\n"
                               "    driver = type('D', (), {'stats': {'decisions': 0}})()\n"
                               "    done = False\n"
                               "    result = {'winner': 0}\n"
                               "    def reset(self, seed=None): return {}\n"
                               "    def menu(self, rich=False): return [{'id': 'pass', 'label': 'Pass'}]\n"
                               "    def step(self, pick):\n"
                               "        d.dm.resolve_pick(self.menu(), pick); self.done = True; return {}, 0.0, True, {}\n"
                               "    def close(self): pass\n"
                               "    def stats(self): return {}\n"
                               "d.reconfigure_streams()\n"
                               "sys.exit(d.interactive(E(), False))\n"],
                              input=b"\xff\xfe\n0\n", capture_output=True, timeout=60)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertNotIn(b"Traceback", done.stderr)
        lines = answers(done.stdout)
        self.assertEqual(len([line for line in lines if "error" in line]), 1, lines)


if __name__ == "__main__":
    unittest.main()
