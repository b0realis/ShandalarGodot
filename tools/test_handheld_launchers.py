"""Offline launcher integration: stub hardware/runtime commands, not the game.

No actual mount, privilege escalation, firmware change or download is performed.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class HandheldLaunchersTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="handheld-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.ports = self.root / "ports with spaces"
        self.game = self.ports / "shandalar"
        self.game.mkdir(parents=True)
        self.pm = self.root / "PortMaster"
        (self.pm / "libs").mkdir(parents=True)
        (self.pm / "libs/weston_pkg_0.2.squashfs").write_bytes(b"fixture")
        (self.pm / "control.txt").write_text('''
ESUDO=""
GPTOKEYB="$SG_TEST_BIN/mapper"
DISPLAY_WIDTH=720
DISPLAY_HEIGHT=720
get_controls() { :; }
pm_platform_helper() { printf 'platform-helper\\n' >> "$SG_TEST_TRACE"; }
pm_finish() { printf 'finish\\n' >> "$SG_TEST_TRACE"; }
pm_message() { printf '%s\\n' "$*"; }
# PortMaster's own scripts use here-documents; bash keeps those in TMPDIR.
read -r sg_test_tmp <<< "$TMPDIR"
printf 'tmpdir %s\\n' "$sg_test_tmp" >> "$SG_TEST_TRACE"
''')
        shutil.copyfile(ROOT / "packaging/handhelds/arkos.sh", self.ports / "Shandalar.sh")
        (self.game / "Shandalar.pck").write_bytes(b"fixture")
        (self.game / "shandalar.gptk").write_bytes(b"fixture")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.trace = self.root / "trace"
        self.env = {**os.environ, "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
                    "SHANDALAR_PORTMASTER": str(self.pm), "SG_TEST_BIN": str(self.bin),
                    "SG_TEST_TRACE": str(self.trace), "SG_TEST_ROOT": str(self.root),
                    "SG_TEST_EXIT": "0",
                    # A full system drive: no here-document can be written there.
                    "TMPDIR": str(self.root / "no-such-drive")}
        self.script(self.bin / "uname", 'printf aarch64\n')
        self.script(self.bin / "mapper", 'printf "mapper\\n" >> "$SG_TEST_TRACE"\n')
        self.script(self.bin / "mount", '''
printf 'mount\\n' >> "$SG_TEST_TRACE"
[[ -z "$SG_TEST_MOUNT_FAIL" ]] || exit 7
for last; do :; done
printf '%s' "$last" > "$SG_TEST_ROOT/mount-target"
cp "$SG_TEST_ROOT/westonwrap.sh" "$last/westonwrap.sh"
cp "$SG_TEST_ROOT/version.txt" "$last/version.txt"
''')
        self.script(self.bin / "umount", '''
printf 'unmount\\n' >> "$SG_TEST_TRACE"
# Only the two fixture files from this test's fake mount.
unlink "$1/westonwrap.sh"
unlink "$1/version.txt"
''')
        self.script(self.root / "westonwrap.sh", '''
if [[ "$1" == cleanup ]]; then
    printf 'cleanup\\n' >> "$SG_TEST_TRACE"
    exit 0
fi
printf 'start\\n' >> "$SG_TEST_TRACE"
[[ "$CRUSTY_SHOW_CURSOR" == 1 ]] || exit 10
[[ "$1 $2 $3 $4" == 'headless noop kiosk crusty_x11egl' ]] || exit 11
shift 4
exec env "$@"
''')
        (self.root / "version.txt").write_text("wp_support26=true\n")
        executable = self.game / "Shandalar.arm64"
        executable.write_text(f"#!{sys.executable}\n" + '''import json, os, sys
from pathlib import Path
Path(os.environ['SG_TEST_ROOT'], 'game-call.json').write_text(json.dumps({
 'args': sys.argv[1:], 'cwd': os.getcwd(),
 'xdg': os.environ.get('XDG_DATA_HOME'),
 'cache': os.environ.get('XDG_CACHE_HOME'), 'tmpdir': os.environ.get('TMPDIR'),
 'ignore': os.environ.get('SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT'),
 'handheld': os.environ.get('SHANDALAR_HANDHELD')}))
sys.exit(int(os.environ['SG_TEST_EXIT']))
''')
        executable.chmod(0o755)

    def script(self, path, text):
        path.write_text("#!/bin/bash\n" + text)
        path.chmod(0o755)

    def launch(self, *args):
        return subprocess.run(["bash", str(self.ports / "Shandalar.sh"), *args],
                              env=self.env, cwd=self.root, capture_output=True,
                              text=True, timeout=15)

    def events(self):
        lines = self.trace.read_text().splitlines() if self.trace.exists() else []
        return [line for line in lines if not line.startswith('tmpdir ')]

    def traced_tmpdir(self):
        lines = self.trace.read_text().splitlines() if self.trace.exists() else []
        return [line[len('tmpdir '):] for line in lines if line.startswith('tmpdir ')]

    def test_launch_scopes_input_and_saves_and_preserves_arguments(self):
        result = self.launch("--custom", "one argument with spaces")
        self.assertEqual(result.returncode, 0, (self.game / "portmaster.log").read_text())
        call = json.loads((self.root / "game-call.json").read_text())
        self.assertEqual(call['cwd'], str(self.game.resolve()))
        self.assertEqual(Path(call['xdg']).resolve(), (self.game / 'conf').resolve())
        self.assertEqual(Path(call['cache']).resolve(), (self.game / 'conf/cache').resolve(),
                         'the shader cache stays off the system drive')
        self.assertEqual(call['ignore'], '0xffff/0xffff')
        self.assertEqual(call['handheld'], 'arkos', 'the handheld defaults (game/settings.gd)')
        self.assertEqual(call['args'][-2:], ['--custom', 'one argument with spaces'])
        for flag, value in (('--display-driver', 'x11'), ('--resolution', '720x720'),
                            ('--max-fps', '30'), ('--rendering-driver', 'opengl3_es')):
            self.assertEqual(call['args'][call['args'].index(flag) + 1], value)
        self.assertNotIn('--main-pack', call['args'])
        self.assertIn('cleanup', self.events())
        self.assertIn('unmount', self.events())
        self.assertEqual(self.events()[-1], 'finish')

    def test_temporary_files_live_beside_the_game_not_on_the_system_drive(self):
        # An R36 Ultra with a full system partition: bash could not create the
        # temp file behind a here-string, control.txt came up half-read and the
        # launcher reported a missing controller mapper. Everything temporary
        # now lives under the game folder on the ports drive.
        result = self.launch()
        self.assertEqual(result.returncode, 0, (self.game / "portmaster.log").read_text())
        tmp = (self.game / 'tmp').resolve()
        self.assertEqual([Path(t).resolve() for t in self.traced_tmpdir()], [tmp],
                         'TMPDIR is set before control.txt is read')
        call = json.loads((self.root / "game-call.json").read_text())
        self.assertEqual(Path(call['tmpdir']).resolve(), tmp)
        target = Path((self.root / 'mount-target').read_text())
        self.assertEqual(target.resolve().parent, tmp, 'the runtime mounts beside the game too')
        self.assertFalse(tmp.exists(), 'a clean exit leaves no tmp folder behind')
        self.assertFalse((self.root / 'no-such-drive').exists())
        self.assertNotIn('<<', (ROOT / 'packaging/handhelds/arkos.sh').read_text(),
                         'no here-document of our own in the launcher')

    def test_full_system_drive_is_reported_in_the_log(self):
        self.script(self.bin / 'df', 'printf "fs 1K used avail use mount\\n/dev/x 100 90 %s 99%% /\\n" "$SG_TEST_FREE"\n')
        self.env['SG_TEST_FREE'] = '100'
        self.assertEqual(self.launch().returncode, 0)
        self.assertIn('system drive is full', (self.game / 'portmaster.log').read_text())
        self.env['SG_TEST_FREE'] = '5000000'
        self.assertEqual(self.launch().returncode, 0)
        self.assertNotIn('system drive is full', (self.game / 'portmaster.log').read_text())

    def test_installed_mapper_is_used_when_control_txt_did_not_export_it(self):
        text = (self.pm / 'control.txt').read_text().replace('GPTOKEYB="$SG_TEST_BIN/mapper"',
                                                               'GPTOKEYB=""\nESUDOKILL="-1"')
        (self.pm / 'control.txt').write_text(text)
        self.script(self.pm / 'gptokeyb', 'printf "gptokeyb %s\\n" "$*" >> "$SG_TEST_TRACE"\n')
        result = self.launch()
        self.assertEqual(result.returncode, 0, (self.game / "portmaster.log").read_text())
        self.assertIn(f'gptokeyb -1 Shandalar.arm64 -c {self.game / "shandalar.gptk"}', self.events())
        self.assertNotIn('mapper', self.events())

    def test_missing_mapper_is_named_before_the_game_starts(self):
        text = (self.pm / 'control.txt').read_text().replace('GPTOKEYB="$SG_TEST_BIN/mapper"',
                                                               'GPTOKEYB=""')
        (self.pm / 'control.txt').write_text(text)
        result = self.launch()
        self.assertNotEqual(result.returncode, 0)
        log = (self.game / 'portmaster.log').read_text()
        self.assertIn('gptokeyb', log)
        self.assertIn('portmaster.log', log)
        self.assertNotIn('start', self.events())
        self.assertFalse((self.root / 'game-call.json').exists())

    def test_game_failure_is_preserved_after_cleanup(self):
        self.env['SG_TEST_EXIT'] = '23'
        self.assertEqual(self.launch().returncode, 23)
        self.assertEqual(self.events()[-3:], ['cleanup', 'unmount', 'finish'])

    def test_mount_failure_does_not_unmount_or_clean_another_runtime(self):
        self.env['SG_TEST_MOUNT_FAIL'] = '1'
        self.assertNotEqual(self.launch().returncode, 0)
        self.assertEqual(self.events(), ['mount', 'finish'])
        self.assertFalse((self.root / 'game-call.json').exists())

    def test_old_runtime_is_refused_and_unmounted(self):
        (self.root / 'version.txt').write_text('wp_support26=false\n')
        self.assertNotEqual(self.launch().returncode, 0)
        self.assertEqual(self.events(), ['mount', 'unmount', 'finish'])

    def test_secondary_runtime_used_if_controlfolder_changes(self):
        second = self.root / 'second'
        second.mkdir()
        with (self.pm / 'control.txt').open('a') as file:
            file.write(f'controlfolder="{second}"\n')
        self.assertEqual(self.launch().returncode, 0)
        self.assertIn('start', self.events())

    def test_missing_runtime_refused_without_starting_game(self):
        (self.pm / 'libs/weston_pkg_0.2.squashfs').unlink()
        self.assertNotEqual(self.launch().returncode, 0)
        self.assertNotIn('start', self.events())

    def test_wrong_architecture_refused(self):
        self.script(self.bin / 'uname', 'printf x86_64\n')
        self.assertNotEqual(self.launch().returncode, 0)
        self.assertFalse(self.events())

    def test_previous_launch_log_preserved_and_profile_untouched(self):
        (self.game / 'portmaster.log').write_text('previous')
        profile = self.game / 'conf/godot/app_userdata/Shandalar/settings.cfg'
        profile.parent.mkdir(parents=True)
        profile.write_text('player settings')
        self.assertEqual(self.launch().returncode, 0)
        self.assertEqual((self.game / 'portmaster.previous.log').read_text(), 'previous')
        self.assertEqual(profile.read_text(), 'player settings')

    def test_steam_launcher_location_and_argument_forwarding(self):
        self.script(self.game / 'Shandalar.x86_64',
                    'printf "%s\\n" "$PWD" "handheld=${SHANDALAR_HANDHELD:-unset}" "$@"\n')
        shutil.copyfile(ROOT / 'packaging/handhelds/steam-deck.sh', self.game / 'run.sh')
        env = {k: v for k, v in os.environ.items() if k != 'SHANDALAR_HANDHELD'}
        result = subprocess.run(['sh', str(self.game / 'run.sh'), 'one argument'], env=env,
                                cwd=self.root, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = result.stdout.splitlines()
        self.assertEqual(Path(lines[0]).resolve(), self.game.resolve())
        self.assertEqual(lines[1], 'handheld=steam-deck', 'the handheld defaults (game/settings.gd)')
        self.assertEqual(lines[-1], 'one argument')
        self.assertIn('1280x800', lines)
        self.assertIn('60', lines)

    def test_all_launchers_parse(self):
        for name in ('arkos.sh', 'steam-deck.sh'):
            result = subprocess.run(['bash', '-n', str(ROOT / 'packaging/handhelds' / name)],
                                    capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)



class ArkosMappingTest(unittest.TestCase):
    """The shipped gptokeyb map: what each ArkOS button types into the game.

    The R36 Ultra tester (2026-10-08) had to press the power button to
    leave the game and asked for a shortcut that opens the pause menu
    directly: Select is Q, the duel's own pause key (`duel_pause`, which
    opens the menu whatever else is going on) and the Deck Builder's menu
    key; Start stays Escape.
    """

    def mapping(self):
        out = {}
        for line in (ROOT / "packaging/handhelds/shandalar.gptk").read_text().splitlines():
            line = line.split("#", 1)[0].strip()
            if "=" in line:
                key, value = line.split("=", 1)
                out[key.strip()] = value.strip()
        return out

    def test_select_opens_the_pause_menu_and_start_is_escape(self):
        mapping = self.mapping()
        self.assertEqual(mapping.get("back"), "q")
        self.assertEqual(mapping.get("start"), "esc")

    def test_q_is_still_the_duels_pause_key(self):
        project = (ROOT / "project.godot").read_text()
        start = project.index("duel_pause={")
        binding = project[start:project.index("}\n", start)]
        self.assertIn('"keycode":81', binding, "Q (keycode 81) opens the duel's pause menu")

    def test_no_two_buttons_type_the_same_key(self):
        typed = [value for value in self.mapping().values()
                 if value not in ('"', "") and not value.startswith("mouse_")
                 and not value.replace(".", "").isdigit()
                 and value not in ("scaled_radial",)]
        self.assertEqual(len(typed), len(set(typed)), typed)

if __name__ == '__main__':
    unittest.main()
