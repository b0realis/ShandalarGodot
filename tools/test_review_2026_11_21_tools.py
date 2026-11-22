#!/usr/bin/env python3
"""The whole-project review of 2026-11-21, the shell scripts' two findings.

  * `run_tests.sh`: a deal that failed for a later shard ended the script
    with a plain exit and left the shards already started running their
    Godot for up to SUITE_TIMEOUT. They are stopped and waited for now.
  * `tools/expansion_lab.sh`: a plugin copy that failed half-way (an --out
    inside the plugin's own folder) ended the script under `set -e` before
    the line that removes the copy. The copy goes however the run ends.

No Godot runs here: a stub stands in for it. Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_review_2026_11_21_tools.py'
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent

## Godot's stand-in: the import and the pack reset answer at once; the GUT
## run writes its process id to $FAKE_PID and then waits, as a long suite does.
WAITING_GODOT = r"""#!/bin/sh
for arg in "$@"; do
	case "$arg" in
		--import) exit 0 ;;
		*reset_test_packs.gd) exit 0 ;;
	esac
done
case " $* " in
	*gut_cmdln.gd*)
		echo $$ >"$FAKE_PID"
		exec sleep 120 ;;
esac
exit 9
"""

## tools/deal_tests.py's stand-in: shard 1 is dealt one script; shard 2
## waits until shard 1's Godot runs, then fails.
FAILING_DEAL = r"""import os, sys, time
if sys.argv[2] == "1":
    print("res://tests/unit/test_one.gd", end="")
    sys.exit(0)
for _ in range(300):
    if os.path.exists(os.environ["FAKE_PID"]):
        break
    time.sleep(0.1)
sys.exit(1)
"""


def alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def quiet_env(**extra) -> dict:
    env = dict(os.environ, SHANDALAR_NO_BANNER="1")
    env.update(extra)
    return env


class RunTestsStopsItsShardsTest(unittest.TestCase):
    """A tree of its own: `run_tests.sh` and the files of tools/ linked from
    this checkout, tools/deal_tests.py replaced by one that fails for shard 2."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        scratch = Path(self.tmp.name)
        self.stub = scratch / "godot"
        self.stub.write_text(WAITING_GODOT)
        self.stub.chmod(0o755)
        self.tree = scratch / "tree"
        (self.tree / "assets" / "original").mkdir(parents=True)
        (self.tree / "tools").mkdir()
        for entry in TOOLS.iterdir():
            if entry.name not in ("deal_tests.py", "__pycache__"):
                (self.tree / "tools" / entry.name).symlink_to(entry)
        (self.tree / "tools" / "deal_tests.py").write_text(FAILING_DEAL)
        (self.tree / "project.godot").symlink_to(ROOT / "project.godot")
        (self.tree / "run_tests.sh").symlink_to(ROOT / "run_tests.sh")
        for name in ("tests/unit/test_one.gd", "tests/ui/test_two.gd"):
            (self.tree / name).parent.mkdir(parents=True, exist_ok=True)
            (self.tree / name).write_text("extends GutTest\n")
        self.pid_file = scratch / "godot.pid"
        self.env = quiet_env(GODOT=str(self.stub), SHANDALAR_TEST_DATA_HOME=str(scratch / "data"),
                             TMPDIR=str(scratch), FAKE_PID=str(self.pid_file), SHARDS="2")
        self.env.pop("SHARD", None)

    def test_a_deal_that_fails_stops_the_shards_already_started(self):
        started = time.monotonic()
        done = subprocess.run(["bash", str(self.tree / "run_tests.sh")], cwd=str(self.tree), env=self.env,
                              stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=110)
        pid = int(self.pid_file.read_text()) if self.pid_file.exists() else 0
        if pid:
            self.addCleanup(lambda: alive(pid) and os.kill(pid, 15))
        self.assertEqual(done.returncode, 1, done.stdout[-2000:] + done.stderr)
        self.assertIn("SUITE IS NOT GREEN: could not deal shard 2 of 2.", done.stderr)
        self.assertTrue(pid, "shard 1's Godot was started before shard 2's deal failed")
        for _ in range(50):
            if not alive(pid):
                break
            time.sleep(0.1)
        self.assertFalse(alive(pid), "shard 1's Godot is stopped with the run")
        self.assertLess(time.monotonic() - started, 100, "and the run did not wait for it to end by itself")


class ExpansionLabCleansItsCopyTest(unittest.TestCase):
    def test_a_copy_that_fails_leaves_no_plugin_copy(self):
        with tempfile.TemporaryDirectory() as tmp:
            plugin = Path(tmp) / "Some_Plugin"
            plugin.mkdir()
            (plugin / "plugin.json").write_text("{}\n")
            # --out inside the plugin's folder: cp cannot copy a folder into itself.
            out = plugin / "out"
            done = subprocess.run(["bash", str(TOOLS / "expansion_lab.sh"), "--out", str(out), "--plugin", str(plugin)],
                                  cwd=str(ROOT), env=quiet_env(GODOT=str(Path(tmp) / "no-godot"), TMPDIR=tmp),
                                  stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=60)
            self.assertNotEqual(done.returncode, 0, done.stdout + done.stderr)
            self.assertFalse((out / "plugin").exists(), "the half-made copy is gone: " + done.stderr)
            self.assertEqual(sorted(p.name for p in plugin.iterdir()), ["out", "plugin.json"])

    def test_the_trap_is_set_before_the_copy(self):
        text = (TOOLS / "expansion_lab.sh").read_text(encoding="utf-8")
        self.assertLess(text.index("trap 'rm -rf -- \"$out/plugin\"' EXIT"), text.index('cp -R -P -- "$plugin"'))


if __name__ == "__main__":
    unittest.main()
