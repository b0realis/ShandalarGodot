"""ArkOS's Select types the game's menu key, not a letter (bug campaign 2026-10-12, b1-8).

Select used to type `q` — the duel's pause key and the Deck Builder's menu
key — and a focused text field (the Deck Builder's search, after the
on-screen keyboard) took it as a letter: the menu that holds Exit game did
not open. Select now types F10, which the game reads as its menu key
(`Controls.MENU_KEY`) wherever Q would open a menu, and which no text
field types. These pin the three places that must agree.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def gptk_mapping():
    out = {}
    for line in (ROOT / "packaging/handhelds/shandalar.gptk").read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if "=" in line:
            key, value = line.split("=", 1)
            out[key.strip()] = value.strip()
    return out


class SelectIsTheMenuKeyTest(unittest.TestCase):
    def test_select_types_f10(self):
        self.assertEqual(gptk_mapping().get("back"), "f10")

    def test_no_other_button_types_f10(self):
        typed = [button for button, value in gptk_mapping().items() if value == "f10"]
        self.assertEqual(typed, ["back"])

    def test_the_game_reads_f10_as_its_menu_key(self):
        controls = (ROOT / "game/input/controls.gd").read_text()
        self.assertRegex(controls, r"const MENU_KEY := KEY_F10\b")
        self.assertIn('if action == "duel_pause" and is_menu_key(event):', controls,
                      "the duel's pause key answers F10")
        builder = (ROOT / "game/deck_builder/deck_builder_screen.gd").read_text()
        handler = builder[builder.index("func _unhandled_key_input"):]
        handler = handler[:handler.index("\nfunc ", 1)]
        self.assertIn("Controls.is_menu_key(event)", handler,
                      "the Deck Builder's menu answers F10")

    def test_the_handheld_doc_names_select_as_the_menu_key(self):
        doc = (ROOT / "docs/handhelds.md").read_text()
        row = next(line for line in doc.splitlines() if line.startswith("| Select |"))
        self.assertIn("F10", row)
        self.assertNotRegex(row, r"\bQ:")


if __name__ == "__main__":
    unittest.main()
