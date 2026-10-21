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

Since the 2026-10-12 hunt it is as strict as real adb in the ways that
broke the scripts: a second device of any state (unauthorized, offline)
fails every command without a serial; the headset has a quota, its `df`
reports it and its `cp` stops at it leaving what it wrote; a push can die
half way; the headset can stop answering mid-run. The tests below pin the
fixes: never half a zip in place, "out of space" said as such, the one
ready headset pinned, only the packs the game reads copied, the clean
install's room counted after step 1, and the docs' by-hand recipe.
"""
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PUSH = ROOT / "packaging/handhelds/push_to_quest.sh"
FRESH = ROOT / "packaging/handhelds/quest_fresh_install.sh"
GAME = "sdcard/Android/data/com.b0realis.shandalar"

FAKE_ADB = r"""#!/bin/bash
# The stand-in adb. "The headset" is __ROOT__/sdcard.
#  FAKE_DEVICES  lines "SERIAL STATE" (default one ready headset)
#  FAKE_QUOTA_KB the headset's whole storage in KB (default: room for anything)
#  FAKE_PUSH_DIE 1: every push dies half way (the cable pulled)
#  FAKE_DOWN_ON  an adb verb (uninstall, push…): from that call on the headset
#                stops answering, as one that went to sleep does
#  FAKE_NO_DF    1: the headset's df prints nothing
#  FAKE_NO_REPORT 1: the game writes no start report
# Like real adb (2026-10-12 hunt, r5): EVERY transport counts when choosing
# the one target — a second device, unauthorized or offline, makes every
# command without -s / ANDROID_SERIAL fail "more than one device/emulator".
# `adb shell` joins its words with spaces and the headset's sh parses them;
# a failed push leaves no file; the headset's cp leaves whatever it wrote.
ROOT=__ROOT__
echo "$*" >> "$ROOT/adb-calls.log"
DEVS=${FAKE_DEVICES:-FAKEQUEST1 device}
serial=${ANDROID_SERIAL:-}
if [ "$1" = -s ]; then serial=$2; shift 2; fi
map() { sed "s#/sdcard#$ROOT/sdcard#g"; }
used_kb() { du -sk "$ROOT/sdcard" | cut -f1; }
if [ "$1" = devices ]; then printf 'List of devices attached\n'; printf '%s\n' "$DEVS" | awk 'NF { print $1 "\t" $2 }'; echo; exit 0; fi
n=$(printf '%s\n' "$DEVS" | grep -c .)
if [ -z "$serial" ] && [ "$n" -gt 1 ]; then echo "adb: more than one device/emulator" >&2; exit 1; fi
state=$(printf '%s\n' "$DEVS" | awk -v s="$serial" 'NF && (s == "" || $1 == s) { print $2; exit }')
case "$state" in
  device) ;;
  unauthorized) echo "adb: device unauthorized." >&2; exit 1 ;;
  offline) echo "adb: device offline" >&2; exit 1 ;;
  *) echo "adb: device '$serial' not found" >&2; exit 1 ;;
esac
if [ -e "$ROOT/down" ] || [ "${FAKE_DOWN_ON:-}" = "$1" ]; then
  touch "$ROOT/down"; echo "adb: device offline" >&2; exit 1
fi
copy_quota() {  # SRC DST: 0 whole, 1 cut short (what was written is left)
  local size free
  size=$(wc -c < "$1")
  if [ -n "${FAKE_QUOTA_KB:-}" ]; then
    free=$(( FAKE_QUOTA_KB - $(used_kb) ))
    if [ $(( size / 1024 )) -gt "$free" ]; then
      head -c $(( free > 0 ? free * 1024 : 0 )) "$1" > "$2"; return 1
    fi
  fi
  cp "$1" "$2"
}
case "$1" in
  uninstall) rm -rf "$ROOT/sdcard/Android/data/$2"; echo Success ;;
  install) echo "Performing Streamed Install"; echo Success; touch "$ROOT/installed" ;;
  push)
    case "$3" in /sdcard/Android/data/*)
      echo "adb: error: failed to copy '$2' to '$3': remote fchown failed: Operation not permitted"; exit 1 ;;
    esac
    dst=$(printf '%s' "$3" | map)
    if [ "${FAKE_PUSH_DIE:-}" = 1 ]; then
      rm -f "$dst"; echo "adb: error: failed to copy '$2' to '$3': connection reset"; exit 1
    fi
    if copy_quota "$2" "$dst"; then echo "$2: 1 file pushed, 0 skipped."
    else rm -f "$dst"; echo "adb: error: failed to copy '$2' to '$3': remote write failed: No space left on device"; exit 1; fi ;;
  pull) src=$(printf '%s' "$2" | map); cp "$src" "$3" ;;
  logcat) [ "${2:-}" = -c ] && exit 0; echo "I/godot: started"; exec sleep 600 ;;
  shell) shift; cmd=$(printf '%s ' "$@" | map)
    case "$cmd" in
      am\ *) exit 0 ;;
      monkey\ *)
        F=$ROOT/sdcard/Android/data/com.b0realis.shandalar/files
        mkdir -p "$F/skin" "$F/cardpacks" "$F/portraits" "$F/music"
        [ -n "${FAKE_NO_REPORT:-}" ] || printf 'android: started\n' > "$F/start_report.txt" ;;
      *) # the headset's df and cp keep to the quota; its cp leaves what it wrote
        FAKE_ROOT="$ROOT" bash -c '
          df() {
            [ -n "${FAKE_NO_DF:-}" ] && return 1
            local total=${FAKE_QUOTA_KB:-99999999} u
            u=$(du -sk "$FAKE_ROOT/sdcard" | cut -f1)
            printf "Filesystem 1K-blocks Used Available Use%% Mounted on\n/dev/fuse %d %d %d 1%% /storage/emulated\n" "$total" "$u" $(( total - u ))
          }
          cp() {
            local s="$1" d="$2" size free
            [ -d "$d" ] && d="$d/$(basename "$s")"
            if [ -n "${FAKE_QUOTA_KB:-}" ]; then
              size=$(wc -c < "$s")
              : > "$d"
              free=$(( FAKE_QUOTA_KB - $(du -sk "$FAKE_ROOT/sdcard" | cut -f1) ))
              if [ $(( size / 1024 )) -gt "$free" ]; then
                head -c $(( free > 0 ? free * 1024 : 0 )) "$s" > "$d"
                echo "cp: $d: No space left on device" >&2; return 1
              fi
            fi
            command cp "$s" "$d"
          }
          '"$cmd" ;;
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
        self.make_package(base / "Shandalar-9.9.9-meta-quest", {
            "skin/original_skin.zip": 3000, "skin/cardart.zip": 2000,
            "cardpacks/Pack-1-DotP-complete.zip": 5000,
            "cardpacks/Pack-9-Tempest-Block.zip": 4000})

    def make_package(self, folder, zips):
        """The unpacked meta-quest package at [folder], with these zips."""
        self.folder = folder
        (self.folder / "skin").mkdir(parents=True)
        (self.folder / "cardpacks").mkdir()
        for script in (PUSH, FRESH):
            target = self.folder / script.name
            target.write_bytes(script.read_bytes())
            target.chmod(0o755)
        (self.folder / "Shandalar.apk").write_bytes(b"apk")
        (self.folder / "VERSION.txt").write_text("9.9.9\n")
        self.zips = dict(zips)
        for name, size in self.zips.items():
            (self.folder / name).write_bytes(os.urandom(size))

    def tearDown(self):
        self.temp.cleanup()

    def env(self, **extra):
        env = {k: v for k, v in os.environ.items()
               if k != "ANDROID_SERIAL" and not k.startswith("FAKE_")}
        env["PATH"] = f"{self.bin}{os.pathsep}{os.environ['PATH']}"
        env.update(extra)
        return env

    def run_script(self, script, stdin="", **extra):
        return subprocess.run(["bash", str(self.folder / script)], cwd=self.folder, env=self.env(**extra),
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

    def test_the_word_yes_is_a_yes_at_every_question(self):
        # HUNT 2026-10-21: step 1 asks for the whole word "yes", and a player
        # types it again at the [y/n] questions — where only `y` counted:
        # "yes" to "Did it reach the title screen?" ended the run with "it
        # did not reach the title screen. Keep these two files".
        result = self.run_script("quest_fresh_install.sh", "yes\n\n\nyes\n\n\n\nYes\n")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("did not reach the title screen", result.stdout)
        self.assertNotIn("black screen", result.stdout)
        self.assertIn("is installed", result.stdout)

    def test_a_missing_start_report_is_not_named_as_a_file_to_keep(self):
        # HUNT 2026-10-21: after "no start report on the headset" the
        # closing lines still named start_report-<stamp>.txt to keep.
        result = self.run_script("quest_fresh_install.sh", "yes\n\n\ny\n\n\n\nn\n",
                                 FAKE_NO_REPORT="1")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("no start report on the headset", result.stdout)
        self.assertFalse(list(self.folder.glob("start_report-*.txt")))
        closing = result.stdout[result.stdout.index("did not reach the title screen"):]
        self.assertNotIn("start_report-", closing)

    def test_fresh_install_deletes_nothing_without_yes(self):
        old = self.device / GAME / "files/cardpacks/Pack-0-old.zip"
        old.parent.mkdir(parents=True)
        old.write_bytes(b"old")
        result = self.run_script("quest_fresh_install.sh", "no\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("nothing was deleted", result.stdout)
        self.assertTrue(old.exists())
        self.assertNotIn("uninstall", (self.device / "adb-calls.log").read_text())


    # ---------------------------------------------- 2026-10-12 hunt (r5, b1) --

    def used_kb(self):
        return int(subprocess.run(["du", "-sk", str(self.device / "sdcard")], capture_output=True,
                                  text=True, check=True).stdout.split()[0])

    def only(self, name, size):
        """A package holding just [name]: the other zips are taken out."""
        for other in list(self.zips):
            (self.folder / other).unlink()
        self.zips = {name: size}
        (self.folder / name).write_bytes(os.urandom(size))

    def test_out_of_space_is_said_before_anything_is_copied(self):
        # r5-2: a headset short of room. The old script pushed anyway, its
        # cp truncated the working zip in place and the message said only
        # "did not arrive". Now the room is read first — twice the file
        # while it is copied, and some to spare — and the old copy stays.
        self.make_game_folders()
        self.only("skin/cardart.zip", 250_000)
        old = os.urandom(200_000)
        self.on_device("skin/cardart.zip").write_bytes(old)
        result = self.run_script("push_to_quest.sh", FAKE_QUOTA_KB=str(self.used_kb() + 2600))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("out of space", result.stdout)
        self.assertEqual(self.on_device("skin/cardart.zip").read_bytes(), old, "the working copy is untouched")
        self.assertNotIn("push ", (self.device / "adb-calls.log").read_text(), "nothing was sent")

    def test_a_copy_cut_short_on_the_headset_never_replaces_the_working_zip(self):
        # r5-2: the room could not be read, the push fits, the headset's own
        # copy runs out of space half way. The copy goes to a .part file and
        # is moved into place only whole: the old zip survives, nothing
        # half-copied or staged is left, and the message says space.
        self.make_game_folders()
        self.only("skin/cardart.zip", 250_000)
        old = os.urandom(200_000)
        self.on_device("skin/cardart.zip").write_bytes(old)
        result = self.run_script("push_to_quest.sh", FAKE_NO_DF="1",
                                 FAKE_QUOTA_KB=str(self.used_kb() + 300))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("out of space", result.stdout)
        self.assertEqual(self.on_device("skin/cardart.zip").read_bytes(), old, "the working copy is untouched")
        skin = self.device / GAME / "files/skin"
        self.assertEqual(sorted(p.name for p in skin.iterdir()), ["cardart.zip"], "no .part left behind")
        staged = self.device / "sdcard/Download/shandalar-push"
        self.assertFalse(staged.exists() and any(staged.iterdir()), "the Download copy is cleared")

    def test_a_push_that_dies_leaves_the_working_zip(self):
        self.make_game_folders()
        self.only("cardpacks/Pack-9-Tempest-Block.zip", 4000)
        old = os.urandom(3000)
        self.on_device("cardpacks/Pack-9-Tempest-Block.zip").write_bytes(old)
        result = self.run_script("push_to_quest.sh", FAKE_PUSH_DIE="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.on_device("cardpacks/Pack-9-Tempest-Block.zip").read_bytes(), old)

    def test_a_second_device_does_not_stop_the_update(self):
        # r5-3: the headset and an unauthorized phone. The count saw one
        # ready headset; every later adb call failed "more than one
        # device/emulator" and the install's hint blamed the signatures.
        self.make_game_folders()
        result = self.run_script("push_to_quest.sh",
                                 FAKE_DEVICES="2G0YC1ZF0F00XX device\nR58M12345 unauthorized")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("headset 2G0YC1ZF0F00XX", result.stdout)
        for name in self.zips:
            self.assertEqual(self.on_device(name).read_bytes(), (self.folder / name).read_bytes(), name)

    def test_a_clean_install_beside_an_offline_emulator(self):
        # r5-3: step 1 printed "it was not installed" and "its folders are
        # gone" while nothing had reached the headset.
        old = self.device / GAME / "files/cardpacks/Pack-0-old.zip"
        old.parent.mkdir(parents=True)
        old.write_bytes(b"old")
        result = self.run_script("quest_fresh_install.sh", "yes\n\n\ny\n\n\n\ny\n",
                                 FAKE_DEVICES="2G0YC1ZF0F00XX device\nemulator-5554 offline")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("uninstalled", result.stdout)
        self.assertFalse(old.exists())
        for name in self.zips:
            self.assertEqual(self.on_device(name).read_bytes(), (self.folder / name).read_bytes(), name)

    def test_step_1_stops_when_the_headset_stops_answering(self):
        # r5-3: an adb error in step 1 is an error, not "it was not
        # installed" and "its folders are gone".
        old = self.device / GAME / "files/cardpacks/Pack-0-old.zip"
        old.parent.mkdir(parents=True)
        old.write_bytes(b"old")
        result = self.run_script("quest_fresh_install.sh", "yes\n\n\ny\n\n\n\ny\n", FAKE_DOWN_ON="uninstall")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("STOPPED", result.stdout)
        self.assertNotIn("it was not installed", result.stdout)
        self.assertNotIn("its folders are gone", result.stdout)
        self.assertNotIn("Step 2", result.stdout)
        self.assertTrue(old.exists(), "nothing was deleted")

    def test_only_the_packs_the_game_reads_are_copied(self):
        # r5-4: a browser's duplicate "Pack-9-Tempest-Block (1).zip", in a
        # folder with spaces and brackets. The device commands were not
        # quoted: "reached the Download folder with no bytes" though it had
        # arrived, and the game would ignore that name anyway.
        self.temp2 = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp2.cleanup)
        self.make_package(Path(self.temp2.name) / "My Quest Stuff" / "Shandalar 0.50.19 (meta quest)", {
            "skin/original_skin.zip": 3000,
            "cardpacks/Pack-1-DotP-complete.zip": 5000,
            "cardpacks/Pack-1-DotP-complete (1).zip": 5000,
            "cardpacks/Pack-9-Tempest-Block (1).zip": 4000,
            "cardpacks/Pack-3-Ice_Age.zip": 3500})
        self.make_game_folders()
        result = self.run_script("push_to_quest.sh")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for name in ("skin/original_skin.zip", "cardpacks/Pack-1-DotP-complete.zip", "cardpacks/Pack-3-Ice_Age.zip"):
            self.assertEqual(self.on_device(name).read_bytes(), (self.folder / name).read_bytes(), name)
        packs = sorted(p.name for p in (self.device / GAME / "files/cardpacks").iterdir())
        self.assertEqual(packs, ["Pack-1-DotP-complete.zip", "Pack-3-Ice_Age.zip"])
        self.assertIn("Pack-9-Tempest-Block (1).zip", result.stdout)
        self.assertIn("rename it to Pack-9-Tempest-Block.zip", result.stdout)
        self.assertIn("Pack-1-DotP-complete (1).zip", result.stdout)
        self.assertIn("3 copied, 0 already there", result.stdout)
        self.assertFalse((self.device / "sdcard/Download/shandalar-push").exists())

    def test_the_scripts_know_every_pack_the_game_reads(self):
        # r5-4's list must follow the game's: a Pack 10 added to game/ and
        # not here would never reach a headset.
        names = set()
        for script in (ROOT / "game").rglob("*.gd"):
            for match in re.finditer(r'const FILE_NAME := "(Pack-[0-9]+-[^"]+\.zip)"', script.read_text()):
                names.add(match.group(1))
        self.assertEqual(len(names), 9, names)
        for script in (PUSH, FRESH):
            listed = set(re.findall(r"\bPack-[0-9]+-[A-Za-z_-]+\.zip\b", script.read_text()))
            self.assertEqual(listed, names, script.name)

    def test_the_fresh_install_counts_what_step_1_frees(self):
        # r5-8: a 3 MB old install and a headset just short of the room the
        # new one needs: the check came before step 1 and refused a
        # headset that would have had room once the old game was gone.
        old = self.device / GAME / "files/cardpacks/Pack-0-old.zip"
        old.parent.mkdir(parents=True)
        old.write_bytes(os.urandom(3 * 1024 * 1024))
        need_kb = 102400 + 64     # the 100 MB kept free, the zips, the APK
        quota = self.used_kb() + need_kb - 1024
        result = self.run_script("quest_fresh_install.sh", "yes\n\n\ny\n\n\n\ny\n", FAKE_QUOTA_KB=str(quota))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for name in self.zips:
            self.assertEqual(self.on_device(name).read_bytes(), (self.folder / name).read_bytes(), name)

    def test_the_fresh_install_names_a_shortfall_to_a_tenth_of_a_megabyte(self):
        # r5-8: whole megabytes printed a refusal as "has 101 MB free; this
        # needs about 101 MB". A tenth, the room rounded down and the need
        # up, never reads as enough.
        quota = self.used_kb() + 100 * 1024
        result = self.run_script("quest_fresh_install.sh", "yes\n", FAKE_QUOTA_KB=str(quota))
        self.assertNotEqual(result.returncode, 0)
        match = re.search(r"has ([0-9]+\.[0-9]) MB free.*needs about ([0-9]+\.[0-9]) MB", result.stdout)
        self.assertIsNotNone(match, result.stdout)
        self.assertLess(float(match.group(1)), float(match.group(2)), match.group(0))
        self.assertNotIn("Step 1", result.stdout, "refused before anything is deleted")

    def test_the_by_hand_recipe_works_without_cardart(self):
        # b1-9: the recipe in docs/handhelds.md ran one cp chain that
        # stopped at the missing cardart.zip — the common case, no package
        # carries one — so no pack was copied and the Download copies
        # stayed.
        (self.folder / "skin/cardart.zip").unlink()
        del self.zips["skin/cardart.zip"]
        doc = (ROOT / "docs/handhelds.md").read_text()
        start = doc.index("By hand, the same three steps")
        block = doc[doc.index("```sh\n", start) + 6:doc.index("```", doc.index("```sh\n", start) + 6)]
        result = subprocess.run(["bash", "-c", block], cwd=self.folder, env=self.env(),
                                capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, block + result.stdout + result.stderr)
        for name in self.zips:
            self.assertEqual(self.on_device(name).read_bytes(), (self.folder / name).read_bytes(), name)
        self.assertFalse((self.device / "sdcard/Download/shandalar-push").exists(), "the Download copies are gone")

if __name__ == "__main__":
    unittest.main()
