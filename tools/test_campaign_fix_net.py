#!/usr/bin/env python3
"""Self-test for the whole-game campaign's network/agent-seat fixes in the
Python tools (2026-10-07, fix-net): `tools/decision_menu.py` (the Driver
behind referee_menu/referee_pick and shandalar_decide) and
`tools/shandalar_mcp.py` (the pass-until stop rule, the game summary).

No Godot and no network. Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'

WHAT THIS HOLDS:

  * THE DRIVER NEVER CONCEDES FOR THE MODEL: with every item refused (a
    LAN host refuses every action while the other seat reconnects) it
    sends the quiet answer and a cancel, then hands the decision back
    with its whole menu — no `concede` on the wire.
  * A SILENCE AT A TABLE IS WAITING, NOT AN ERROR: the MCP link's read
    that times out leaves the Driver with no decision (`waiting`), the
    menu state says `pending`, and a pick sends nothing.
  * MAGNETIC WEB'S COMPANIONS: an attack item declares the creatures its
    pick drags in (`presentation.attack_companions`), and so does the
    quiet answer.
  * EVERY ENGINE KEYWORD HAS A WORD (`shadow` since Pack 9).
  * `until` STOPS IN THE 1997 WINDOWS: the damage-prevention and the
    regeneration window, while something usable is held there — every
    `until` but `mine-strict`.
  * A PAYABLE RANSOM IS HELD: `until: "mine"` stops at the opponent's end
    step for Sabertooth Cobra's ransom or a point of prevention the seat
    can pay (the options' usable-only specials, kinds from
    `presentation.special_rows`); never for Channel; a licid's end only
    over a spell.
  * A CHOICE NAMES ITS CARDS (protocol 29, `choice.cards`): the menu line
    and the compact view carry each line's board handle once, and the
    observation's prompt lists them.
  * A DRAWN SEED is the result's: the game summary reads it from there.
"""

import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import decision_menu as dm  # noqa: E402
import shandalar_mcp as mcp  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
AWAY = "Waiting for the other player to reconnect."


def priority(n: int, lands=("c3",)) -> dict:
    hand = [{"id": h, "name": "Forest", "land": True, "playable": True, "types": 1} for h in lands]
    view = {"mode": "priority", "actor": 0, "active": 0, "turn": 4, "step": "MAIN1", "stack": [],
            "hand": hand, "players": [{"seat": 0, "life": 20, "battlefield": []},
                                      {"seat": 1, "life": 20, "battlefield": []}],
            "presentation": {"cards": [{"id": h, "abilities": [], "castable": False} for h in lands]}}
    options = {"mode": "priority", "concede": True, "pass": {"op": "pass"},
               "play": {"op": "play", "lands": [{"card": h, "name": "Forest"} for h in lands]},
               "prepare": {"op": "prepare", "casts": [], "abilities": []},
               "mana": {"op": "mana", "sources": []}, "special": {"op": "special", "specials": []},
               "respond": False}
    return {"type": "decision", "n": n, "seat": 0, "mode": "priority", "turn": 4, "step": "MAIN1",
            "options": options, "view": view}


class RefusingTable:
    """A referee whose table refuses every action, as a LAN host does while
    the other seat is away; the decision stands."""

    def __init__(self):
        self.sent = []
        self.queue = [{"type": "hello", "seats": []}, priority(9)]

    def send(self, action):
        self.sent.append(action)
        if action.get("op") == "concede":
            self.queue.append({"type": "result", "winner": 1, "reason": "conceded"})
        else:
            self.queue.append({"type": "refused", "n": 9, "seat": 0, "reason": AWAY, "action": action})
            self.queue.append(priority(9))

    def receive(self):
        return self.queue.pop(0) if self.queue else None


class DriverNeverConcedes(unittest.TestCase):
    def test_every_item_refused_hands_the_decision_back(self):
        table = RefusingTable()
        driver = dm.Driver(table.send, table.receive, seats={0})
        driver.start()
        menu = driver.menu()
        play = next(i for i, item in enumerate(menu) if item["id"].startswith("play:"))
        driver.pick(play)
        ops = [a.get("op") for a in table.sent]
        self.assertNotIn("concede", ops, f"the Driver conceded on its own after {ops}")
        self.assertIn("cancel", ops, "the quiet answer and a cancel were tried first")
        self.assertFalse(driver.done, "the game goes on")
        again = [item["id"] for item in driver.menu()]
        self.assertIn("pass", again, "the decision is handed back with its whole menu")
        self.assertIn("play:c3", again)

    def test_the_quiet_answer_never_concedes(self):
        for mode in ("priority", "attack", "block", "choice", "discard", "opening"):
            d = priority(1)
            d["mode"] = d["options"]["mode"] = mode
            self.assertNotEqual(dm.fallback_action(d).get("op"), "concede", mode)


class TableGame:
    """The MCP `Game`'s face while the person at the table thinks: every
    read times out with `pending` (Game.advance's own shape)."""

    def __init__(self, pending):
        self.pending = pending
        self.result = None
        self.error = None
        self.memory = {}
        self.passed_journal = []
        self.fresh = False
        self.sent = []

    def send(self, action):
        self.sent.append(action)
        self.pending = None

    def advance(self, timeout, render=True):
        return {"game": "g1", "pending": True, "note": "nothing arrived in time; referee_wait reads on"}


class SilenceAtATable(unittest.TestCase):
    def test_a_forced_pass_then_silence_is_waiting(self):
        game = TableGame(priority(12, lands=()))
        driver = dm.attach_game(game, timeout=0.1)   # one item: the Driver passes by itself
        self.assertEqual([a.get("op") for a in game.sent], ["pass"])
        self.assertIsNone(driver.decision)
        self.assertTrue(driver.waiting)
        self.assertFalse(driver.done)
        state = dm.menu_state(driver)
        self.assertTrue(state["pending"])
        self.assertEqual(state["menu"], [])
        self.assertEqual(state["obs"]["mode"], "waiting")
        picked = driver.pick("pass")
        self.assertTrue(picked["pending"])
        self.assertIsNone(picked["item"])
        self.assertEqual(len(game.sent), 1, "a pick while waiting sends nothing")
        text = mcp.menu_text({"game": "g1", **state}, None, [])
        self.assertIn("WAITING", text)

    def test_a_pass_until_ends_waiting_for_the_table(self):
        game = TableGame(priority(12))
        driver = dm.attach_game(game, timeout=0.1)
        out = driver.pick("pass", until=lambda d: "")
        self.assertEqual(out["stop"], "waiting for the table")
        self.assertIsNone(driver.decision)

    def test_the_decision_that_arrives_is_taken_up(self):
        game = TableGame(priority(12, lands=()))
        driver = dm.attach_game(game, timeout=0.1)
        self.assertTrue(driver.waiting)
        game.pending = priority(14)
        again = dm.attach_game(game, timeout=0.1)
        self.assertIs(again, driver)
        self.assertFalse(driver.waiting)
        self.assertEqual(driver.decision["n"], 14)
        self.assertIn("play:c3", [item["id"] for item in driver.menu()])


def attack_decision() -> dict:
    cobra = {"id": "c5", "name": "Sabertooth Cobra", "creature": True, "types": 2, "power": 2, "toughness": 2,
             "counters": {"magnet": 1}}
    monk = {"id": "c7", "name": "Soltari Monk", "creature": True, "types": 2, "power": 2, "toughness": 1,
            "counters": {"magnet": 1}, "keywords": [7]}
    bear = {"id": "c9", "name": "Grizzly Bears", "creature": True, "types": 2, "power": 2, "toughness": 2}
    view = {"mode": "attack", "actor": 0, "active": 0, "turn": 6, "step": "DECLARE_ATTACKERS", "stack": [],
            "hand": [], "players": [{"seat": 0, "life": 20, "battlefield": [cobra, monk, bear]},
                                     {"seat": 1, "life": 20, "battlefield": []}],
            "presentation": {"cards": [], "attack_companions": [["c5", ["c7"]], ["c7", ["c5"]]]}}
    options = {"mode": "attack", "concede": True,
               "attack": {"op": "attack", "attackable": [{"card": "c5", "name": "Sabertooth Cobra"},
                                                          {"card": "c7", "name": "Soltari Monk"},
                                                          {"card": "c9", "name": "Grizzly Bears"}]},
               "attack_bands": {"op": "attack_bands", "attackable": ["c5", "c7", "c9"]}}
    return {"type": "decision", "n": 30, "seat": 0, "mode": "attack", "turn": 6, "step": "DECLARE_ATTACKERS",
            "options": options, "view": view}


class MagneticCompanions(unittest.TestCase):
    def test_an_added_attacker_brings_its_companions(self):
        decision = attack_decision()
        decision["view"]["players"][0]["battlefield"][1].pop("keywords")
        menu = dm.build_menu(decision)
        add = next(item for item in menu if item["id"] == "attack:add:c5")
        self.assertIn("with Soltari Monk", add["label"])
        sub_menu = dm.build_menu(decision, add["plan"]["sub"])
        declare = next(item for item in sub_menu if item["id"] == "attack:declare")
        self.assertEqual(sorted(declare["plan"]["send"][0]["cards"]), ["c5", "c7"])
        self.assertNotIn("attack:add:c7", [item["id"] for item in sub_menu], "already dragged in")

    def test_a_creature_that_must_attack_brings_its_companions_too(self):
        decision = attack_decision()   # the Monk must attack (keyword 7)
        menu = dm.build_menu(decision)
        self.assertEqual(menu[0]["id"], "attack:declare")
        self.assertEqual(sorted(menu[0]["plan"]["send"][0]["cards"]), ["c5", "c7"])
        self.assertEqual(sorted(dm.fallback_action(decision)["cards"]), ["c5", "c7"])

    def test_no_companions_no_change(self):
        decision = attack_decision()
        decision["view"]["presentation"].pop("attack_companions")
        decision["view"]["players"][0]["battlefield"][1].pop("keywords")
        sub = dm.build_menu(decision, dm.build_menu(decision)[2]["plan"]["sub"])
        self.assertEqual(len(next(i for i in sub if i["id"] == "attack:declare")["plan"]["send"][0]["cards"]), 1)


class Keywords(unittest.TestCase):
    def test_every_engine_keyword_has_a_word(self):
        text = (ROOT / "engine" / "core" / "mtg.gd").read_text(encoding="utf-8")
        names = [n.strip() for n in re.search(r"enum Keyword \{([^}]*)\}", text).group(1).split(",") if n.strip()]
        self.assertEqual(len(dm.KEYWORDS), len(names))
        for name, word in zip(names, dm.KEYWORDS):
            self.assertEqual(name.lower().replace("_", " "), word)
        self.assertIn("shadow", dm.keyword_words({"keywords": [names.index("SHADOW")]}))


def window_decision(prevention: bool, regeneration: bool, abilities: list) -> dict:
    view = {"turn": 5, "step": "COMBAT_DAMAGE", "active": 1, "actor": 0, "mode": "priority", "stack": [],
            "players": [{"seat": 0, "battlefield": []}, {"seat": 1, "battlefield": []}],
            "presentation": {"prevention": prevention, "regeneration": regeneration, "respond": bool(abilities)}}
    options = {"mode": "priority", "concede": True, "pass": {"op": "pass"}, "play": {"op": "play", "lands": []},
               "prepare": {"op": "prepare", "casts": [], "abilities": abilities},
               "mana": {"op": "mana", "sources": []}, "special": {"op": "special", "specials": []},
               "respond": bool(abilities)}
    return {"type": "decision", "n": 40, "seat": 0, "mode": "priority", "turn": 5, "step": "COMBAT_DAMAGE",
            "options": options, "view": view}


CIRCLE = {"card": "c4", "name": "Circle of Protection: Red", "index": 0, "budget": 0, "cost": "{1}",
          "label": "{1}: The next time a red source would deal damage to you this turn, prevent that damage."}


class WindowStops(unittest.TestCase):
    def test_every_until_but_strict_stops_in_the_prevention_window(self):
        decision = window_decision(True, False, [CIRCLE])
        for until in ("mine", "main", "turn", "end", "play", "respond"):
            reason = mcp.stop_reason(decision, until, decision)
            self.assertIn("damage-prevention window", reason, until)
            self.assertIn("Circle of Protection: Red", reason, until)
        self.assertEqual(mcp.stop_reason(decision, "mine-strict", decision), "")

    def test_the_regeneration_window_too(self):
        decision = window_decision(False, True, [dict(CIRCLE, name="Drudge Skeletons")])
        self.assertIn("regeneration window", mcp.stop_reason(decision, "mine", decision))

    def test_nothing_usable_passes_the_window(self):
        decision = window_decision(True, False, [])
        self.assertEqual(mcp.stop_reason(decision, "mine", decision), "")
        self.assertEqual(mcp.window_stop(decision["options"], decision["view"]), "")

    def test_no_window_no_window_stop(self):
        decision = window_decision(False, False, [CIRCLE])
        self.assertEqual(mcp.window_stop(decision["options"], decision["view"]), "")


def end_step_decision(specials: list, rows: list, stack: list | None = None) -> dict:
    view = {"turn": 6, "step": "END", "active": 1, "actor": 0, "mode": "priority", "stack": stack or [],
            "players": [{"seat": 0, "battlefield": []}, {"seat": 1, "battlefield": []}],
            "presentation": {"prevention": False, "regeneration": False, "respond": True, "special_rows": rows}}
    options = {"mode": "priority", "concede": True, "pass": {"op": "pass"}, "play": {"op": "play", "lands": []},
               "prepare": {"op": "prepare", "casts": [], "abilities": []},
               "mana": {"op": "mana", "sources": []},
               "special": {"op": "special", "specials": [{"index": i, "label": l} for i, l in enumerate(specials)]},
               "respond": True}
    return {"type": "decision", "n": 50, "seat": 0, "mode": "priority", "turn": 6, "step": "END",
            "options": options, "view": view}


class RansomHeld(unittest.TestCase):
    RANSOM = "Pay {2}: Sabertooth Cobra: pay {2} before your next upkeep or get a poison counter"

    def test_mine_stops_at_their_end_step_for_a_payable_ransom(self):
        decision = end_step_decision([self.RANSOM], [["settle", "c5"]])
        reason = mcp.stop_reason(decision, "mine", decision)
        self.assertIn("their end", reason)
        self.assertIn("Pay {2}", reason)
        self.assertEqual(mcp.stop_reason(decision, "mine-strict", decision), "")

    def test_channel_is_not_a_response(self):
        decision = end_step_decision(["Channel — pay 1 life for one colorless mana"], [["channel", ""]])
        decision["options"]["respond"] = False
        self.assertEqual(mcp.stop_reason(decision, "mine", decision), "")

    def test_a_licid_s_end_only_over_a_spell(self):
        rows = [["licid_end", "c8"]]
        quiet = end_step_decision(["Pay {R}: end Convulsing Licid's effect"], rows)
        self.assertEqual(mcp.specials_held(quiet["options"], quiet["view"]), [])
        busy = end_step_decision(["Pay {R}: end Convulsing Licid's effect"], rows,
                                 [{"name": "Lightning Bolt", "controller": 1}])
        self.assertEqual(len(mcp.specials_held(busy["options"], busy["view"])), 1)


def namesake_choice() -> dict:
    view = {"mode": "choice", "actor": 0, "active": 0, "turn": 3, "step": "MAIN1", "stack": [], "hand": [],
            "players": [{"seat": 0, "battlefield": []}, {"seat": 1, "battlefield": []}],
            "choice": {"prompt": "Select creature to sacrifice.", "source": "Ashnod's Altar",
                       "options": ["Grizzly Bears — yours [c12]", "Grizzly Bears — yours [c13]"], "count": 1,
                       "cancel": True, "information": [], "cards": ["c12", "c13"]},
            "presentation": {"cards": []}}
    options = {"mode": "choice", "concede": True,
               "choice": {"op": "choice", "prompt": "Select creature to sacrifice.", "source": "Ashnod's Altar",
                          "options": view["choice"]["options"], "count": 1, "information": [],
                          "cards": ["c12", "c13"]},
               "cancel": {"op": "cancel"}}
    return {"type": "decision", "n": 60, "seat": 0, "mode": "choice", "turn": 3, "step": "MAIN1",
            "options": options, "view": view}


class ChoiceCards(unittest.TestCase):
    def test_a_line_names_its_board_card_once(self):
        menu = dm.build_menu(namesake_choice())
        lines = {item["id"]: item for item in menu}
        self.assertEqual(lines["choice:0"]["label"], "Grizzly Bears — yours [c12]", "not named twice")
        self.assertEqual(lines["choice:1"]["info"]["card"], "c13")
        self.assertEqual(dm.encode_observation(namesake_choice())["prompt"]["cards"], ["c12", "c13"])

    def test_an_older_label_gets_the_handle_beside_it(self):
        decision = namesake_choice()
        decision["options"]["choice"]["options"] = ["Grizzly Bears — yours [choice 1]",
                                                    "Grizzly Bears — yours [choice 2]"]
        decision["view"]["choice"]["options"] = decision["options"]["choice"]["options"]
        labels = [item["label"] for item in dm.build_menu(decision) if item["id"].startswith("choice:")
                  and item["id"] != "choice:cancel"]
        self.assertEqual(labels, ["Grizzly Bears — yours [choice 1] [c12]", "Grizzly Bears — yours [choice 2] [c13]"])
        text = mcp.compact_view(decision)
        self.assertIn("0: Grizzly Bears — yours [choice 1] [c12]", text)


class DrawnSeed(unittest.TestCase):
    def test_the_summary_names_the_result_s_seed(self):
        game = mcp.Game.__new__(mcp.Game)

        class Closed:
            alive = False
        for key, value in {"ident": "g1", "transport": Closed(), "closed": True, "view": "brief",
                           "decisions": 3, "refusals": 0, "keep": None,
                           "started": 0.0, "argv": ["referee"], "table": None,
                           "hello": {"type": "hello", "seed": -1, "seats": []}, "pending": None,
                           "result": {"type": "result", "seed": 4242}, "error": None}.items():
            setattr(game, key, value)
        self.assertEqual(game.summary()["seed"], 4242)
        game.result = None
        self.assertEqual(game.summary()["seed"], -1, "before the result: hello's -1, nothing more")


if __name__ == "__main__":
    unittest.main()
