"""The ArkOS launcher says why when PortMaster's own files fail (2026-10-12).

`packaging/handhelds/arkos.sh` sources PortMaster's `control.txt` and the
firmware's `mod_<CFW>.txt`, then calls their `get_controls`. Each of the
three stopped the launcher with `exit 1` and nothing written, so a tester's
`portmaster.log` came back EMPTY — the one launch failure with no reason
in the file the docs ask for (hunt r5-6). Run against a stand-in PortMaster,
WestonPack and mount, as tools/test_handheld_launchers.py does; nothing is
mounted or installed.
"""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

CONTROL = '''CFW_NAME=ArkOS
ESUDO=""
GPTOKEYB="$SG_TEST_BIN/mapper"
DISPLAY_WIDTH=720
DISPLAY_HEIGHT=720
get_controls() { return "${SG_TEST_CONTROLS_RC:-0}"; }
'''


class ArkosPortMasterFailuresTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="arkos-c2-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.ports = self.root / "ports"
        self.game = self.ports / "shandalar"
        self.game.mkdir(parents=True)
        self.pm = self.root / "PortMaster"
        (self.pm / "libs").mkdir(parents=True)
        (self.pm / "libs/weston_pkg_0.2.squashfs").write_bytes(b"fixture")
        (self.pm / "control.txt").write_text(CONTROL)
        shutil.copyfile(ROOT / "packaging/handhelds/arkos.sh", self.ports / "Shandalar.sh")
        (self.game / "Shandalar.pck").write_bytes(b"fixture")
        (self.game / "shandalar.gptk").write_bytes(b"fixture")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.started = self.root / "game-started"
        self.script(self.bin / "uname", 'printf aarch64\n')
        self.script(self.bin / "mapper", 'exit 0\n')
        self.script(self.bin / "mount", 'for last; do :; done\n'
                    'cp "$SG_TEST_ROOT/westonwrap.sh" "$SG_TEST_ROOT/version.txt" "$last/"\n')
        self.script(self.bin / "umount", 'rm -f "$1/westonwrap.sh" "$1/version.txt"\n')
        self.script(self.root / "westonwrap.sh", '[[ "$1" == cleanup ]] && exit 0\nshift 4\nexec env "$@"\n')
        (self.root / "version.txt").write_text("wp_support26=true\n")
        executable = self.game / "Shandalar.arm64"
        executable.write_text(f"#!{sys.executable}\nimport pathlib, os\n"
                              "pathlib.Path(os.environ['SG_TEST_ROOT'], 'game-started').write_text('yes')\n")
        executable.chmod(0o755)
        self.env = {**os.environ, "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
                    "SHANDALAR_PORTMASTER": str(self.pm), "SG_TEST_BIN": str(self.bin),
                    "SG_TEST_ROOT": str(self.root), "TMPDIR": str(self.root / "tmp")}

    def script(self, path, text):
        path.write_text("#!/bin/bash\n" + text)
        path.chmod(0o755)

    def launch(self, **extra):
        return subprocess.run(["bash", str(self.ports / "Shandalar.sh")], env={**self.env, **extra},
                              cwd=self.root, capture_output=True, text=True, timeout=15)

    def log(self):
        return (self.game / "portmaster.log").read_text()

    def test_the_fixture_launches(self):
        result = self.launch()
        self.assertEqual(result.returncode, 0, self.log())
        self.assertTrue(self.started.exists())

    def test_get_controls_failing_is_named_in_the_log(self):
        result = self.launch(SG_TEST_CONTROLS_RC="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.started.exists())
        log = self.log()
        self.assertIn("Shandalar:", log)
        self.assertIn("get_controls", log)
        self.assertIn("PortMaster", log)

    def test_control_txt_failing_is_named_in_the_log(self):
        (self.pm / "control.txt").write_text(CONTROL + "false\n")
        result = self.launch()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.started.exists())
        log = self.log()
        self.assertIn("Shandalar:", log)
        self.assertIn("control.txt", log)
        self.assertIn(str(self.pm), log, "names which PortMaster it read")

    def test_the_firmwares_mod_file_failing_is_named_in_the_log(self):
        (self.pm / "mod_ArkOS.txt").write_text("false\n")
        result = self.launch()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.started.exists())
        log = self.log()
        self.assertIn("Shandalar:", log)
        self.assertIn("mod_ArkOS.txt", log)


if __name__ == "__main__":
    unittest.main()
