#!/usr/bin/env python3
"""What the export presets keep OUT of the .pck — every preset, by name.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_c3_fx_scripts_export_filter.py'

Found by the repository check of 2026-10-13: every preset in
export_presets.cfg.example exported with `export_filter="all_resources"`
and none of them named `branding/*`, so the two README screenshots (the
optional 1997 skin with card art on it) and the 1.5 MB logo master were
packed into every .pck, APK and web build — about 4 MB of a 15.5 MB
Linux pack. CONTRIBUTING.md: the .pck ships scripts, `cards/data/` and
every `.deck`, never art. Nothing the game runs loads `res://branding`;
the window icon and the boot splash live in `game/`.

The other folders below were already excluded; they are pinned here so a
preset copied from an older file, or a new preset, cannot drop one of them
quietly. `test_build_release_sh.py` pins the two run folders
(`DeckLab/results/*`, `workspace/*`) the same way.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXAMPLE = ROOT / "export_presets.cfg.example"

## Never in a pack: the suite, the developer tools, the docs, the GUT
## addon, the player's own 1997 graphics and card art (`assets/`), and the
## README's screenshots and the logo master (`branding/`).
NEVER_PACKED = ("tests/*", "tools/*", "docs/*", "addons/*", "assets/*", "branding/*")


def presets(text: str) -> dict:
    """{preset name: its exclude_filter entries} for every [preset.N]
    section (not the [preset.N.options] ones)."""
    found = {}
    for section in re.split(r"(?m)^\[preset\.\d+\]\n", text)[1:]:
        name = re.search(r'(?m)^name="([^"]*)"', section)
        exclude = re.search(r'(?m)^exclude_filter="([^"]*)"', section)
        assert name, "a preset section without a name= line"
        found[name.group(1)] = [entry.strip() for entry in exclude.group(1).split(",")] \
            if exclude else []
    return found


class ExportFilterTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.presets = presets(EXAMPLE.read_text(encoding="utf-8"))

    def test_the_example_has_presets(self):
        self.assertIn("Linux 64", self.presets)
        self.assertIn("Android Quest", self.presets)

    def test_every_preset_leaves_branding_out_of_the_pack(self):
        for name, entries in self.presets.items():
            with self.subTest(preset=name):
                self.assertIn("branding/*", entries,
                              "%s packs branding/ (the README screenshots and the logo master)" % name)

    def test_every_preset_keeps_the_development_folders_out(self):
        for name, entries in self.presets.items():
            for folder in NEVER_PACKED:
                with self.subTest(preset=name, folder=folder):
                    self.assertIn(folder, entries)

    def test_nothing_the_game_runs_loads_branding(self):
        # The exclusion is only safe while this holds: a scene or script
        # that loaded `res://branding/...` would find nothing in an export.
        users = []
        for folder in ("game", "engine", "cards", "DeckLab"):
            for path in sorted((ROOT / folder).rglob("*")):
                if path.suffix in (".gd", ".tscn", ".tres") and \
                        "res://branding" in path.read_text(encoding="utf-8", errors="replace"):
                    users.append(str(path.relative_to(ROOT)))
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        if "res://branding" in project:
            users.append("project.godot")
        self.assertEqual(users, [])


if __name__ == "__main__":
    unittest.main()
