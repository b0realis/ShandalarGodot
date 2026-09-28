"""MCP regression cases for slow referees, malformed inputs and deck browsing."""
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import shandalar_mcp as mcp


class RobustnessTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.server = mcp.Server(self.root / "shandalar.sh", self.root / "workspace")
        self.addCleanup(self.server.shutdown)

    def test_typed_arguments_are_refused_before_starting_or_writing(self):
        cases = [("lab", {"games": True}), ("lab", {"games": 1.5}),
                 ("lab", {"timeout": -1}), ("lab", {"timeout": 0}),
                 ("lab", {"timeout": float("nan")}), ("lab", {"timeout": float("inf")}),
                 ("lab", {"rated": "false"}), ("lab", {"argv": [1]}),
                 ("list_decks", {"folder": 5}), ("list_decks", {"limit": 0}),
                 ("list_decks", {"offset": -1}), ("cards", {"names": []}),
                 ("cards", {"names": [None]})]
        with mock.patch.object(self.server, "run") as run:
            for name, args in cases:
                with self.subTest(name=name, args=args), self.assertRaises(mcp.ToolError):
                    self.server.call(name, args)
            run.assert_not_called()

    def test_deck_rows_cannot_inject_lines_or_truncate_counts(self):
        for row in ({"count": 1.5, "name": "Island"}, {"count": True, "name": "Island"},
                    {"count": 1, "name": None}, {"count": 1, "name": "Island\n99 Black Lotus"},
                    {"name": "Island\rSB: 1 Mountain"}, {"name": "Island\u2028name: Changed"}):
            with self.subTest(row=row), self.assertRaises(mcp.ToolError):
                mcp.deck_rows([row], "write_deck", "cards")
        with self.assertRaises(mcp.ToolError):
            self.server.call("write_deck", {"file": "injected.deck", "name": "X\n40 Island",
                                             "cards": ["1 Mountain"], "check": False})
        self.assertFalse(self.server.workspace.exists())

    def test_browse_search_pages_and_overlapping_workspace(self):
        folder = self.root / "decks"
        folder.mkdir()
        for i in range(3):
            (folder / f"{i}.deck").write_text(f"name: Blue {i}\n40 Island\n", encoding="utf-8")
        self.server.workspace = folder
        listed = self.server.call("list_decks", {"search": "bLuE", "offset": 1, "limit": 1})
        self.assertEqual(listed["count"], 3)
        self.assertEqual(listed["returned"], 1)
        self.assertEqual(listed["next_offset"], 2)
        self.assertEqual(listed["decks"][0]["file"], "decks/1.deck")
        last = self.server.call("list_decks", {"search": "2.deck", "limit": 1})
        self.assertEqual(last["count"], 1)
        self.assertIsNone(last["next_offset"])
        self.assertEqual(self.server.call("read_deck", {"deck": last["decks"][0]["file"]})["cards"], 40)

    def test_raw_output_flags_cannot_bypass_path_rule(self):
        outside = str(self.root.parent / "not-this-workspace")
        cases = [("lab", {"argv": ["--out"]}),
                 ("lab", {"argv": ["--out", "workspace/good", "--out", outside]}),
                 ("lab", {"extra_args": ["--out=" + outside]}),
                 ("lab", {"argv": ["--resume", outside]}),
                 ("lab", {"extra_args": ["--elo-file", outside]}),
                 ("autodeck", {"out": "workspace/good", "extra_args": ["--out", outside]})]
        with mock.patch.object(self.server, "run") as run:
            for name, args in cases:
                with self.subTest(name=name, args=args), self.assertRaises(mcp.ToolError):
                    self.server.call(name, args)
            run.assert_not_called()

    def test_malformed_query_output_is_not_a_successful_null_result(self):
        for output in ("", "not json", "null", "[]"):
            with self.subTest(output=output), mock.patch.object(self.server, "run", return_value=
                    subprocess.CompletedProcess([], 0, output, "")), self.assertRaises(mcp.ToolError):
                self.server.call("packs", {})

    def test_raw_output_destination_matches_the_last_checked_flag(self):
        argv, out = self.server.lab_argv({"out": "workspace/first", "extra_args": ["--out=workspace/last"]})
        self.assertEqual(out, self.root / "workspace/last")
        self.assertEqual(argv[-3:], ["--out", str(out), "--quiet"])

    def test_raw_lab_is_unrated_unless_explicitly_requested(self):
        argv, _ = self.server.lab_argv({"argv": ["--deck-a", "a.deck", "--dry-run"]})
        self.assertIn("--no-elo", argv)
        argv, _ = self.server.lab_argv({"argv": ["--deck-a", "a.deck"], "rated": True})
        self.assertNotIn("--no-elo", argv)

    def test_bad_protocol_shapes_are_invalid_requests(self):
        for message in ({"jsonrpc": "2.0", "method": 2, "id": 1},
                        {"jsonrpc": "2.0", "method": "ping", "id": []}):
            with self.subTest(message=message):
                self.assertEqual(self.server.handle(message)["error"]["code"], -32600)
        sink = io.StringIO()
        self.server.serve(io.StringIO("[]\n"), sink)
        self.assertEqual(json.loads(sink.getvalue())["error"]["code"], -32600)

    def open_game(self, script):
        game = mcp.Game("test", [sys.executable, "-u", "-c", script], "options",
                        self.root, self.root / "referee.stderr")
        self.server.games[game.ident] = game
        return game

    def test_slow_answer_clears_old_decision_until_wait_reads_the_next(self):
        game = self.open_game(
            "import json, sys, time\n"
            "print(json.dumps({'type':'decision','n':0,'seat':0,'mode':'opening'}), flush=True)\n"
            "sys.stdin.readline()\ntime.sleep(0.3)\n"
            "print(json.dumps({'type':'decision','n':1,'seat':0,'mode':'priority'}), flush=True)\n"
            "sys.stdin.read()\n")
        self.assertEqual(game.advance(3)["decision"]["n"], 0)
        state = self.server.call("referee_act", {"game": "test", "action": {"op": "keep"}, "timeout": .01})
        self.assertTrue(state["pending"])
        self.assertIsNone(game.pending)
        with self.assertRaises(mcp.ToolError):
            self.server.call("referee_act", {"game": "test", "action": {"op": "keep"}})
        state = self.server.call("referee_wait", {"game": "test", "timeout": 3})
        self.assertEqual(state["decision"]["n"], 1)
        self.assertEqual(state["decisions"], 2)

    def test_refused_action_does_not_count_one_decision_twice(self):
        game = self.open_game(
            "import json, sys\n"
            "d={'type':'decision','n':0,'seat':0,'mode':'opening'}\n"
            "print(json.dumps(d), flush=True)\nsys.stdin.readline()\n"
            "print(json.dumps({'type':'refused','n':0}), flush=True)\n"
            "print(json.dumps(d), flush=True)\nsys.stdin.read()\n")
        game.advance(3)
        state = self.server.call("referee_act", {"game": "test", "action": {"op": "wrong"}})
        self.assertEqual(state["decisions"], 1)
        self.assertEqual(state["refusals"], 1)

    def test_eof_without_process_exit_is_bounded_and_cleans_handles(self):
        game = self.open_game("import os, time\nos.close(1)\ntime.sleep(30)\n")
        # An EOF is not proof the child exited. Never wait indefinitely for it.
        state = game.advance(2)
        self.assertEqual(state["error"]["kind"], "run")
        self.assertIsNotNone(game.proc.poll())
        self.assertTrue(game.stderr_file.closed)
        self.assertTrue(game.proc.stdout.closed)
        self.assertFalse(game.pump.is_alive())
        self.assertEqual(game.stderr_tail(), [])

    def test_failed_spawn_is_a_tool_refusal_and_closes_stderr(self):
        opened = []
        def fail(*args, **kwargs):
            opened.append(kwargs["stderr"])
            raise OSError("not executable")
        with mock.patch.object(mcp.subprocess, "Popen", side_effect=fail):
            with self.assertRaises(mcp.ToolError):
                self.open_game("unused")
        self.assertTrue(opened[0].closed)


if __name__ == "__main__":
    unittest.main()
