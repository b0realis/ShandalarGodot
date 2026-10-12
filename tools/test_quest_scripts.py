"""The Meta Quest's two adb scripts, run against a stand-in adb (2026-10-11).

`packaging/handhelds/push_to_quest.sh` (install or update, keeps the game's
settings and decks) and `quest_fresh_install.sh` (a clean install, step by
step) ship in the meta-quest package (`tools/package_release.py`). On the
owner's Quest 3 a direct `adb push` into the game's folder now fails —
"remote fchown failed: Operation not permitted" — so both copy through the
headset's Download folder and `cp` into place.

The stand-in adb below keeps "the headset's" /sdcard in a temporary folder,
runs `adb shell` commands there, and REFUSES a push into
/sdcard/Android/data the way the headset does, so a script that pushes there
fails here as it failed on the owner's headset. `monkey` (starting the game)
makes the game's four folders, as the game does at its start.
"""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PUSH = ROOT / "packaging/handhelds/push_to_quest.sh"
FRESH = ROOT / "packaging/handhelds/quest_fresh_install.sh"
GAME = "sdcard/Android/data/com.b0realis.shandalar"

FAKE_ADB = r"""#!/bin/bash
ROOT=__ROOT__
echo "$*" >> "$ROOT/adb-calls.log"
map() { sed "s#/sdcard#$ROOT/sdcard#g"; }
case "$1" in
  devices) printf 'List of devices attached\nFAKEQUEST1\tdevice\n\n' ;;
  uninstall) rm -rf "$ROOT/sdcard/Android/data/$2"; echo Success ;;
  install) echo "Performing Streamed Install"; echo Success; touch "$ROOT/installed" ;;
  push)
    case "$3" in /sdcard/Android/data/*)
      echo "adb: error: failed to copy '$2' to '$3': remote fchown failed: Operation not permitted"; exit 1 ;;
    esac
    dst=$(printf '%s' "$3" | map); cp "$2" "$dst" && echo "$2: 1 file pushed, 0 skipped." ;;
  pull) src=$(printf '%s' "$2" | map); cp "$src" "$3" ;;
  logcat) [ "${2:-}" = -c ] && exit 0; echo "I/godot: started"; exec sleep 600 ;;
  shell) shift; cmd=$(printf '%s ' "$@" | map)
    case "$cmd" in
      am\ *) exit 0 ;;
      monkey\ *)
        F=$ROOT/sdcard/Android/data/com.b0realis.shandalar/files
        mkdir -p "$F/skin" "$F/cardpacks" "$F/portraits" "$F/music"
        printf 'android: started\n' > "$F/start_report.txt" ;;
      *) bash -c "$cmd" ;;
    esac ;;
esac
"""


class QuestScriptsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        base = Path(self.temp.name)
        self.device = base / "device"
        (self.device / "sdcard/Download").mkdir(parents=True)
        self.bin = base / "bin"
        self.bin.mkdir()
        adb = self.bin / "adb"
        adb.write_text(FAKE_ADB.replace("__ROOT__", str(self.device)))
        adb.chmod(0o755)
        self.folder = base / "Shandalar-9.9.9-meta-quest"
        (self.folder / "skin").mkdir(parents=True)
        (self.folder / "cardpacks").mkdir()
        for script in (PUSH, FRESH):
            target = self.folder / script.name
            target.write_bytes(script.read_bytes())
            target.chmod(0o755)
        (self.folder / "Shandalar.apk").write_bytes(b"apk")
        (self.folder / "VERSION.txt").write_text("9.9.9\n")
        self.zips = {"skin/original_skin.zip": 3000, "skin/cardart.zip": 2000,
                     "cardpacks/Pack-1-DotP-complete.zip": 5000,
                     "cardpacks/Pack-9-Tempest-Block.zip": 4000}
        for name, size in self.zips.items():
            (self.folder / name).write_bytes(os.urandom(size))

    def tearDown(self):
        self.temp.cleanup()

    def run_script(self, script, stdin=""):
        env = dict(os.environ, PATH=f"{self.bin}{os.pathsep}{os.environ['PATH']}")
        return subprocess.run(["bash", str(self.folder / script)], cwd=self.folder, env=env,
                              input=stdin, capture_output=True, text=True, timeout=180)

    def on_device(self, name):
        return self.device / GAME / "files" / ("skin" if name.startswith("skin/") else "cardpacks") \
            / Path(name).name

    def make_game_folders(self):
        for sub in ("skin", "cardpacks", "portraits", "music"):
            (self.device / GAME / "files" / sub).mkdir(parents=True, exist_ok=True)

    def test_the_fake_headset_refuses_a_push_into_the_games_folder(self):
        # The premise: what the owner's headset did to the old script.
        self.make_game_folders()
        env = dict(os.environ, PATH=f"{self.bin}{os.pathsep}{os.environ['PATH']}")
        result = subprocess.run(["adb", "push", "skin/cardart.zip", "/" + GAME + "/files/skin/"],
                                cwd=self.folder, env=env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("remote fchown failed", result.stdout)

    def test_push_copies_every_zip_into_the_games_folders(self):
        self.make_game_folders()
        result = self.run_script("push_to_quest.sh")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for name in self.zips:
            self.assertEqual(self.on_device(name).read_bytes(), (self.folder / name).read_bytes(), name)
        self.assertIn("4 copied, 0 already there", result.stdout)
        self.assertFalse((self.device / "sdcard/Download/shandalar-push").exists(), "the staging folder is gone")
        calls = (self.device / "adb-calls.log").read_text()
        self.assertIn("install -r Shandalar.apk", calls)
        self.assertNotIn("uninstall", calls, "an update keeps the game's settings and decks")

    def test_push_twice_copies_nothing_the_headset_already_holds(self):
        self.make_game_folders()
        self.assertEqual(self.run_script("push_to_quest.sh").returncode, 0)
        changed = self.folder / "cardpacks/Pack-9-Tempest-Block.zip"
        changed.write_bytes(os.urandom(4000))   # the same size, other bytes
        result = self.run_script("push_to_quest.sh")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("1 copied, 3 already there", result.stdout)
        self.assertEqual(self.on_device("cardpacks/Pack-9-Tempest-Block.zip").read_bytes(), changed.read_bytes())

    def test_push_starts_the_game_once_when_its_folders_are_missing(self):
        result = self.run_script("push_to_quest.sh")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = (self.device / "adb-calls.log").read_text()
        self.assertIn("monkey -p com.b0realis.shandalar", calls)
        self.assertLess(calls.index("install -r"), calls.index("monkey"))
        self.assertLess(calls.index("monkey"), calls.index("push "))
        for name in self.zips:
            self.assertTrue(self.on_device(name).exists(), name)

    def test_fresh_install_deletes_installs_and_copies(self):
        old = self.device / GAME / "files/cardpacks/Pack-0-old.zip"
        old.parent.mkdir(parents=True)
        old.write_bytes(b"old")
        # yes, Enter (install), Enter (started once), y (title seen), Enter
        # (copy), Enter (record), Enter (title up), y (reached it)
        result = self.run_script("quest_fresh_install.sh", "yes\n\n\ny\n\n\n\ny\n")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(old.exists(), "everything the game kept was deleted first")
        for name in self.zips:
            self.assertEqual(self.on_device(name).read_bytes(), (self.folder / name).read_bytes(), name)
        calls = (self.device / "adb-calls.log").read_text()
        self.assertLess(calls.index("uninstall"), calls.index("install Shandalar.apk"))
        self.assertTrue(list(self.folder.glob("start_report-*.txt")), "the game's start report is fetched")
        self.assertTrue(list(self.folder.glob("quest-*.log")), "the log is kept")

    def test_fresh_install_deletes_nothing_without_yes(self):
        old = self.device / GAME / "files/cardpacks/Pack-0-old.zip"
        old.parent.mkdir(parents=True)
        old.write_bytes(b"old")
        result = self.run_script("quest_fresh_install.sh", "no\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("nothing was deleted", result.stdout)
        self.assertTrue(old.exists())
        self.assertNotIn("uninstall", (self.device / "adb-calls.log").read_text())


if __name__ == "__main__":
    unittest.main()
