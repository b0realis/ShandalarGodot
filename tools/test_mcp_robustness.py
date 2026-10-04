"""MCP regression cases for slow referees, malformed inputs and deck browsing."""
import io
import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import time
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
                    {"name": "Island\rSB: 1 Mountain"}, {"name": "Island\u2028name: Changed"},
                    {"count": mcp.MAX_COUNT + 1, "name": "Island"}, "5000000 Island"):
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


    # --- the bug pass of 2026-10-03 ------------------------------------------

    def test_a_key_error_inside_a_tool_is_not_an_unknown_tool(self):
        tool = next(t for t in self.server.tools if t["name"] == "status")
        with mock.patch.dict(tool, {"handler": lambda args: {}["missing"]}):
            answer = self.server.handle({"jsonrpc": "2.0", "id": 7, "method": "tools/call",
                                         "params": {"name": "status", "arguments": {}}})
        self.assertEqual(answer["error"]["code"], -32603)
        self.assertNotIn("unknown tool", answer["error"]["message"])
        unknown = self.server.handle({"jsonrpc": "2.0", "id": 8, "method": "tools/call",
                                      "params": {"name": "stauts", "arguments": {}}})
        self.assertEqual(unknown["error"]["code"], -32602)
        self.assertIn("status", unknown["error"]["data"]["suggestions"])

    def test_a_half_written_run_is_a_refusal_not_a_protocol_error(self):
        run = self.server.workspace / "broken"
        run.mkdir(parents=True)
        (run / "run.json").write_text('{"tool": "lab", "exit": nu', encoding="utf-8")
        for name in ("read_run", "lab_next"):
            with self.subTest(name=name), self.assertRaises(mcp.ToolError) as caught:
                self.server.call(name, {"out": str(run)})
            self.assertEqual(caught.exception.envelope["kind"], "run")
        (run / "run.json").write_text("[]", encoding="utf-8")
        with self.assertRaises(mcp.ToolError):
            self.server.call("read_run", {"out": str(run)})

    def test_the_lab_folder_is_found_from_the_line_the_lab_prints(self):
        folder = self.root / "DeckLab" / "results" / "run_5"
        folder.mkdir(parents=True)
        (folder / "run.json").write_text("{}", encoding="utf-8")
        text = "REPORT\n\nwrote DeckLab/results/run_5/{report.txt, results.json, run.json}\n"
        self.assertEqual(self.server.out_from_output(text, ""), folder)
        self.assertIsNone(self.server.out_from_output("no folder here", ""))

    def test_two_servers_on_one_workspace_never_share_a_game_number(self):
        other = mcp.Server(self.root / "shandalar.sh", self.root / "workspace")
        self.addCleanup(other.shutdown)
        with mock.patch.object(mcp, "Game") as game:
            game.side_effect = lambda ident, *rest, **more: mock.Mock(ident=ident)
            first = self.server.new_game(["--deck-a", "a"], "brief")
            second = other.new_game(["--deck-a", "a"], "brief")
            third = self.server.new_game(["--deck-a", "a"], "brief")
        self.assertEqual([first.ident, second.ident, third.ident], ["g1", "g2", "g3"])

    def test_a_kept_socket_closed_while_booting_never_connects(self):
        handshake = self.root / "late.keep.json"
        transport = mcp.SocketTransport(handshake, boot=5)
        lines = []
        reader = threading.Thread(target=lambda: lines.extend(transport.read_lines()), daemon=True)
        reader.start()
        time.sleep(0.3)
        transport.close(0)
        listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.addCleanup(listener.close)
        listener.bind(("127.0.0.1", 0))
        listener.listen(1)
        listener.settimeout(1.5)
        handshake.write_text(json.dumps({"port": listener.getsockname()[1], "token": "t"}), encoding="utf-8")
        with self.assertRaises(socket.timeout):
            conn, _ = listener.accept()
            conn.close()
        reader.join(5)
        self.assertFalse(reader.is_alive())
        self.assertEqual(lines, [])

    def test_a_compact_answer_is_the_content_and_the_json_stays_structured(self):
        # 0.50.13: an MCP client shows `content` to its model — a compact-view
        # referee answer's content is its text, structuredContent its JSON;
        # a refusal may carry its own text the same way.
        answer = mcp.Answer({"game": "g1", "decision": {"n": 3}}, "the board as text")
        result = mcp.tool_result(answer, False)
        self.assertEqual(result["content"], [{"type": "text", "text": "the board as text"}])
        self.assertEqual(result["structuredContent"], {"game": "g1", "decision": {"n": 3}})
        self.assertIs(type(result["structuredContent"]), dict)
        plain = mcp.tool_result({"a": 1}, False)
        self.assertEqual(json.loads(plain["content"][0]["text"]), {"a": 1})
        with mock.patch.object(self.server, "call", side_effect=mcp.ToolError({"kind": "cast", "message": "no"}, "board")):
            reply = self.server.handle({"jsonrpc": "2.0", "id": 4, "method": "tools/call",
                                        "params": {"name": "referee_cast", "arguments": {}}})
        self.assertTrue(reply["result"]["isError"])
        self.assertEqual(reply["result"]["content"][0]["text"], "board")
        self.assertEqual(reply["result"]["structuredContent"], {"error": {"kind": "cast", "message": "no"}})

    def test_a_decision_answered_unseen_hands_its_journal_on(self):
        # 0.50.13: `send` keeps a fresh decision's journal for the next one shown
        game = object.__new__(mcp.Game)
        game.ident, game.view, game.pending, game.fresh, game.passed_journal = "g1", "brief", None, False, []
        game.last_brief = game.delta_base = game.shown_record = None
        game.pending = {"n": 1, "seat": 0, "mode": "priority", "view": {"journal": ["one"]}}
        game.fresh = True
        game.absorb()
        game.absorb()   # (once only)
        self.assertEqual(game.passed_journal, ["one"])
        game.pending = {"n": 2, "seat": 0, "mode": "priority", "view": {"journal": ["two"]}}
        game.fresh = True
        shown = game.shown()
        self.assertEqual(shown["brief"]["journal"], ["one", "two"])
        self.assertFalse(game.fresh)
        game.absorb()   # shown already: nothing kept twice
        self.assertEqual(game.passed_journal, [])

    def test_a_transcript_is_read_from_its_tail(self):
        transcript = self.root / "g9.lines"
        decision = json.dumps({"type": "decision", "n": 1, "view": {"journal": ["x" * 500] * 20}})
        with transcript.open("w", encoding="utf-8") as stream:
            for _ in range(400):
                stream.write(decision + "\n")
        record = {"game": "g9", "lines": str(transcript)}
        real = json.loads
        with mock.patch.object(mcp.json, "loads", side_effect=real) as loads:
            self.assertIsNone(mcp.Server.transcript_result(record))
        self.assertLessEqual(loads.call_count, mcp.Server.TRANSCRIPT_LINES)
        with transcript.open("a", encoding="utf-8") as stream:
            stream.write(json.dumps({"type": "result", "winner": 1, "reason": "idle"}) + "\n")
        self.assertEqual(mcp.Server.transcript_result(record)["reason"], "idle")


if __name__ == "__main__":
    unittest.main()
