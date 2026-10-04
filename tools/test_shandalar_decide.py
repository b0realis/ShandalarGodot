#!/usr/bin/env python3
"""Self-test for the decision-model door — `tools/decision_menu.py` (the
menus, the observation, the Driver) and `tools/shandalar_decide.py` (the
referee bridge: `Env`, the JSON-lines protocol, the policies) — 2026-10-04.

No Godot and no network for everything but `LiveTest`: the menus are
built from REAL referee decision lines recorded into
`tools/fixtures/decide_decisions.json` (protocol 1, trimmed to the keys the
module reads), the Driver is driven against a scripted fake referee, and
the command line against a fake door. `LiveTest` plays complete duels
against the wizard through the real referee — the random and the greedy
policy, core decks and a Pack 8 deck — and is skipped unless
`SHANDALAR_DECIDE_LIVE=1` (it uses an isolated profile:
`SHANDALAR_TEST_DATA_HOME`, else `$TMPDIR/shandalar-test-data`).

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'
    SHANDALAR_DECIDE_LIVE=1 python3 -m unittest tools.test_shandalar_decide.LiveTest

WHAT THIS HOLDS:

  * EVERY ITEM IS A COMPLETE, WELL-FORMED ANSWER: each op an item expands
    to is a referee duel op with exactly the wire's keys; item 0 is the
    mode's "do nothing"; ids are unique and stable across identical
    states (another `n`, another journal: the same ids).
  * THE MENUS: flat `cast S -> T` per candidate from a probe, an
    unreachable or refused probe drops the spell, too many candidates or
    two slots fall back to the target sub-menu, identical hand cards are
    listed once, attack/block/discard/choice picks are sequential
    sub-menus, damage presets, a choice that takes no pick, "another
    target" leaves out an earlier slot's pick, divided damage is split.
  * THE DRIVER: probe (prepare, cancel) then prepare/autopay/submit with
    the live tokens; a refused submit is cancelled at once and the item
    leaves the menu; a payment question goes to the model and the submit
    follows its answer; a menu of one is answered alone; the journal of
    every decision read reaches the next observation; a probe is reused
    for an identical state.
  * THE OBSERVATION: the deciding seat's side, phased-out permanents, a
    tenth of the wire's view, FEATURES/ITEM_FEATURES as long as their
    tables.
  * THE COMMAND LINE: -h names the banner opt-out, --version is the one
    version, the JSON-lines protocol (an index, an id, a bad pick answered
    with an error and the same decision), --policy/--episodes, the
    referee's refusal envelope and exit 2.
  * THE RELEASE ships both tools (`package_release.TOOLS`), and a staged
    copy answers --version beside the modules it imports.
"""

import copy
import json
import os
import random
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import decision_menu as dm  # noqa: E402
import shandalar_decide as sd  # noqa: E402
import tool_banner  # noqa: E402

TOOLS_DIR = Path(__file__).resolve().parent
ROOT = TOOLS_DIR.parent
SCRIPT = TOOLS_DIR / "shandalar_decide.py"
FIXTURE = TOOLS_DIR / "fixtures" / "decide_decisions.json"
LIVE = os.environ.get("SHANDALAR_DECIDE_LIVE") == "1"

# The wire's own keys per duel op (game/sgmanalink/protocol.gd FIELDS) and
# the referee's duel ops (DeckLab/referee.gd DUEL_OPS).
FIELDS = {"keep": [], "mulligan": [], "pass": [], "play": ["card"], "tap": ["card"],
          "attack": ["cards"], "block": ["pairs"], "damage": ["points"], "discard": ["cards"],
          "concede": [], "prepare": ["card", "kind", "index", "x", "mode"], "submit": ["targets"],
          "cancel": [], "choice": ["picks"], "attack_bands": ["cards", "bands"], "special": ["index"],
          "order": ["play"], "mana": ["card", "index"], "autopay": ["excluded", "count"],
          "autoprepare": ["card", "kind", "index", "mode", "excluded", "count"]}


def fixture() -> dict:
    return json.loads(FIXTURE.read_text(encoding="utf-8"))


def decision(name: str) -> dict:
    return copy.deepcopy(fixture()["decisions"][name])


def probe_records(d: dict) -> dict:
    """The fixture's recorded probe answers for the decision's probe rows."""
    probes = fixture()["probes"]
    out = {}
    for row in dm.probe_actions(d):
        key = json.dumps(row["action"], sort_keys=True)
        if key in probes:
            out[row["key"]] = dm.probe_record(probes[key])
    return out


def announcement_for(d: dict, card: str) -> dict:
    """The recorded announcement decision the priority fixture's probe of
    `card` was answered with."""
    for key, value in fixture()["probes"].items():
        if json.loads(key)["card"] == card:
            return copy.deepcopy(value)
    raise KeyError(card)


def ids(menu) -> list:
    return [item["id"] for item in menu]


def giant_growth(menu) -> list:
    """The items that cast the priority fixture's Giant Growth (c1)."""
    return [i for i in ids(menu) if i == "cast:c1" or i.startswith("cast:c1->")]


class FixtureTest(unittest.TestCase):
    def test_the_fixture_is_real_referee_lines(self):
        data = fixture()
        self.assertGreaterEqual(len(data["decisions"]), 10)
        modes = {d["mode"] for d in data["decisions"].values()}
        self.assertEqual(modes, {"opening", "priority", "attack", "block", "discard", "damage", "choice"})
        for d in data["decisions"].values():
            self.assertEqual(d["type"], "decision")
            self.assertIn("options", d)
            self.assertIn("presentation", d["view"])


class MenuShapeTest(unittest.TestCase):
    def menus(self):
        for name, d in fixture()["decisions"].items():
            yield name, d, dm.build_menu(d, probes=probe_records(d) if dm.probe_actions(d) else None)

    def test_every_op_is_a_duel_op_with_the_wires_keys(self):
        for name, _d, menu in self.menus():
            self.assertTrue(menu, name)
            for item in menu:
                self.assertTrue(item["id"] and item["label"], name)
                if "sub" in item["plan"]:
                    self.assertEqual(item["ops"], [], f"{name}: {item['id']} is a sub-menu step")
                else:
                    self.assertTrue(item["ops"], f"{name}: {item['id']} expands to ops")
                for op in item["ops"]:
                    self.assertIn(op["op"], FIELDS, f"{name}: {item['id']}")
                    self.assertEqual(set(op) - {"op"}, set(FIELDS[op["op"]]), f"{name}: {item['id']}: {op}")

    def test_ids_are_unique_and_item_zero_does_nothing(self):
        quiet = {"opening": ("order:play", "keep"), "priority": ("pass", "target:you"),
                 "attack": ("attack:none",), "block": ("block:none",), "damage": ("damage:ordered",)}
        for name, d, menu in self.menus():
            self.assertEqual(len(ids(menu)), len(set(ids(menu))), name)
            if d["mode"] in quiet:
                self.assertIn(menu[0]["id"], quiet[d["mode"]], name)

    def test_ids_are_stable_across_identical_states(self):
        for name, d in fixture()["decisions"].items():
            again = copy.deepcopy(d)
            again["n"] = d["n"] + 40
            again["view"]["journal"] = [{"serial": 999, "text": "something else happened"}]
            probes = probe_records(d) if dm.probe_actions(d) else None
            self.assertEqual(ids(dm.build_menu(d, probes=probes)), ids(dm.build_menu(again, probes=probes)), name)
            self.assertEqual(dm.fingerprint(d), dm.fingerprint(again), name)

    def test_the_public_menu_is_id_and_label(self):
        menu = dm.build_menu(decision("attack"))
        self.assertEqual(dm.public_menu(menu)[0], {"id": "attack:none", "label": "No attack"})
        rich = dm.public_menu(menu, rich=True)[1]
        self.assertEqual(rich["kind"], "attack_all")
        self.assertEqual(rich["ops"], [{"op": "attack", "cards": ["c2", "c7"]}])


class PriorityMenuTest(unittest.TestCase):
    def setUp(self):
        self.d = decision("priority_main")

    def test_an_aimed_spell_is_listed_once_per_candidate(self):
        menu = dm.build_menu(self.d, probes=probe_records(self.d))
        self.assertEqual(ids(menu), ["pass", "play:c7", "cast:c1->c2", "cast:c1->c12", "cast:c1->c5",
                                     "cast:c10", "cast:c13"])
        bolt = menu[2]
        self.assertEqual(bolt["label"], "Cast Giant Growth → Llanowar Elves — yours")
        self.assertEqual(bolt["ops"][0], {"op": "prepare", "card": "c1", "kind": "spell", "index": 0, "x": 0, "mode": 0})
        self.assertEqual(bolt["ops"][2], {"op": "submit", "targets": [["t0", 0]]})
        self.assertEqual(bolt["info"]["target"]["side"], "me")
        self.assertEqual(menu[3]["info"]["target"]["side"], "opp")

    def test_only_spells_that_may_aim_are_probed(self):
        rows = dm.probe_actions(self.d)
        self.assertEqual([r["key"] for r in rows], ["cast:c1"])
        self.assertEqual(dm.probe_actions(decision("attack")), [])

    def test_an_unreachable_or_refused_probe_drops_the_spell(self):
        for record in ({"refused": "This action is unavailable."},
                       {**probe_records(self.d)["cast:c1"], "reachable": False}):
            menu = dm.build_menu(self.d, probes={"cast:c1": record})
            self.assertFalse(giant_growth(menu), record)
            self.assertIn("cast:c10", ids(menu))

    def test_without_probes_an_aimed_spell_is_one_item_and_a_sub_menu(self):
        menu = dm.build_menu(self.d, probes=None)
        item = menu[ids(menu).index("cast:c1")]
        self.assertIsNone(item["plan"]["targets"])
        self.assertTrue(item["label"].endswith("(choose targets)"))

    def test_too_many_candidates_fall_back_to_the_sub_menu(self):
        record = probe_records(self.d)["cast:c1"]
        slot = record["announcement"]["slots"][0]
        slot["targets"] = [{"id": f"t{i}", "label": f"Card {i}"} for i in range(dm.MAX_FLAT_TARGETS + 1)]
        menu = dm.build_menu(self.d, probes={"cast:c1": record})
        self.assertIn("cast:c1", ids(menu))
        self.assertFalse([i for i in ids(menu) if i.startswith("cast:c1->")])

    def test_an_optional_target_offers_the_untargeted_cast_too(self):
        record = probe_records(self.d)["cast:c1"]
        record["announcement"]["slots"][0]["min"] = 0
        menu = dm.build_menu(self.d, probes={"cast:c1": record})
        self.assertIn("cast:c1", ids(menu))
        self.assertIn("cast:c1->c2", ids(menu))

    def test_no_legal_target_drops_the_spell(self):
        record = probe_records(self.d)["cast:c1"]
        record["announcement"]["slots"][0]["targets"] = []
        menu = dm.build_menu(self.d, probes={"cast:c1": record})
        self.assertFalse(giant_growth(menu))

    def test_identical_hand_cards_are_listed_once(self):
        d = self.d
        twin = copy.deepcopy(next(c for c in d["view"]["hand"] if c["id"] == "c10"))
        twin["id"] = "c40"
        d["view"]["hand"].append(twin)
        row = copy.deepcopy(next(r for r in d["view"]["presentation"]["cards"] if r["id"] == "c10"))
        row["id"] = "c40"
        d["view"]["presentation"]["cards"].append(row)
        cast = copy.deepcopy(next(c for c in d["options"]["prepare"]["casts"] if c["card"] == "c10"))
        cast["card"] = "c40"
        d["options"]["prepare"]["casts"].append(cast)
        menu = dm.build_menu(d, probes=probe_records(d))
        self.assertIn("cast:c10", ids(menu))
        self.assertNotIn("cast:c40", ids(menu))

    def test_x_and_modes_expand(self):
        self.assertEqual(dm.x_values(0), [0])
        self.assertEqual(dm.x_values(3), [1, 2, 3])
        spread = dm.x_values(20)
        self.assertEqual((spread[0], spread[-1], len(spread)), (1, 20, dm.MAX_X_CHOICES))
        d = self.d
        cast = next(c for c in d["options"]["prepare"]["casts"] if c["card"] == "c10")
        cast["x"], cast["budget"], cast["modes"] = True, 2, ["Deal damage", "Gain life"]
        menu = ids(dm.build_menu(d, probes=probe_records(d)))
        for ident in ("cast:c10:m0:x1", "cast:c10:m0:x2", "cast:c10:m1:x1", "cast:c10:m1:x2"):
            self.assertIn(ident, menu)

    def test_a_modal_cast_is_offered_only_in_its_usable_modes(self):
        # Recorded: Spinning Darkness with "Pay {4}{B}{B}" unaffordable and
        # "Exile the top three black cards" payable — usable_modes [1].
        d = decision("priority_modes")
        cast = next(c for c in d["options"]["prepare"]["casts"] if c["card"] == "c4")
        self.assertEqual(cast["usable_modes"], [1])
        menu = dm.build_menu(d, probes=None)
        spinning = [i for i in ids(menu) if i.startswith("cast:c4")]
        self.assertEqual(spinning, ["cast:c4:m1"])         # the id keeps the mode's own index
        item = menu[ids(menu).index("cast:c4:m1")]
        self.assertEqual(item["ops"][0]["mode"], 1)
        self.assertEqual(item["info"]["mv"], 0)            # that mode's own cost, {0}
        self.assertIn("Exile the top three black cards", item["label"])
        self.assertEqual([r["action"]["mode"] for r in dm.probe_actions(d) if r["action"]["card"] == "c4"], [1])
        cast["usable_modes"] = [0, 1]
        self.assertIn("cast:c4:m0", ids(dm.build_menu(d, probes=None)))
        cast["usable_modes"] = []
        self.assertFalse([i for i in ids(dm.build_menu(d, probes=None)) if i.startswith("cast:c4")])
        del cast["usable_modes"]                           # an older referee: every mode, as before
        self.assertEqual([i for i in ids(dm.build_menu(d, probes=None)) if i.startswith("cast:c4")],
                         ["cast:c4:m0", "cast:c4:m1"])

    def test_specials_and_blocked_keys(self):
        d = self.d
        d["options"]["special"] = {"op": "special", "specials": [{"index": 0, "label": "Channel — pay 1 life"}]}
        menu = dm.build_menu(d, probes=probe_records(d))
        self.assertEqual(menu[-1]["ops"], [{"op": "special", "index": 0}])
        blocked = {"cast:c1", dm.blocked_key(menu[-1])}
        left = ids(dm.build_menu(d, probes=probe_records(d), blocked=blocked))
        self.assertNotIn("special:0", left)
        self.assertFalse([i for i in left if i == "cast:c1" or i.startswith("cast:c1->")])


class SubMenuTest(unittest.TestCase):
    def test_attack_is_one_creature_at_a_time(self):
        d = decision("attack")
        menu = dm.build_menu(d)
        self.assertEqual(ids(menu), ["attack:none", "attack:all", "attack:add:c2", "attack:add:c7"])
        sub = menu[2]["plan"]["sub"]
        self.assertEqual(menu[2]["ops"], [])
        menu = dm.build_menu(d, sub)
        self.assertEqual(ids(menu), ["attack:declare", "attack:add:c7"])
        self.assertEqual(menu[0]["ops"], [{"op": "attack", "cards": ["c2"]}])
        # A sub-menu of another decision is ignored.
        other = copy.deepcopy(d)
        other["n"] += 1
        self.assertEqual(ids(dm.build_menu(other, sub))[0], "attack:none")

    def test_a_creature_that_must_attack_is_already_chosen(self):
        d = decision("attack")
        card = next(c for c in d["view"]["players"][0]["battlefield"] if c["id"] == "c7")
        card["keywords"] = [dm.KW_MUST_ATTACK]
        menu = dm.build_menu(d)
        self.assertEqual(menu[0]["id"], "attack:declare")
        self.assertEqual(menu[0]["ops"], [{"op": "attack", "cards": ["c7"]}])
        self.assertNotIn("attack:none", ids(menu))
        self.assertEqual(dm.fallback_action(d), {"op": "attack", "cards": ["c7"]})

    def test_blocks_are_one_pair_at_a_time(self):
        d = decision("block")
        menu = dm.build_menu(d)
        self.assertEqual(ids(menu), ["block:none", "block:c2->c9", "block:c7->c9", "block:c4->c9"])
        menu = dm.build_menu(d, menu[1]["plan"]["sub"])
        self.assertEqual(ids(menu), ["block:declare", "block:c7->c9", "block:c4->c9"])
        menu = dm.build_menu(d, menu[2]["plan"]["sub"])
        self.assertEqual(menu[0]["ops"], [{"op": "block", "pairs": [["c2", "c9"], ["c4", "c9"]]}])

    def test_discard_picks_until_the_count(self):
        d = decision("discard")
        menu = dm.build_menu(d)
        self.assertEqual(menu[0]["ops"], [{"op": "discard", "cards": ["c14"]}])
        self.assertNotIn("discard:c21", ids(menu))   # a second Lightning Bolt is the same card
        d["options"]["discard"]["count"] = 2
        menu = dm.build_menu(d)
        first = menu[0]
        self.assertIn("sub", first["plan"])
        menu = dm.build_menu(d, first["plan"]["sub"])
        self.assertIn("discard:c21", ids(menu))      # now the other Bolt is a pick of its own
        last = menu[ids(menu).index("discard:c21")]
        self.assertEqual(last["ops"], [{"op": "discard", "cards": ["c14", "c21"]}])

    def test_choices(self):
        menu = dm.build_menu(decision("choice_cost"))
        self.assertEqual(ids(menu), ["choice:0", "choice:1", "choice:cancel"])
        self.assertEqual(menu[1]["ops"], [{"op": "choice", "picks": [1]}])
        self.assertEqual(menu[2]["ops"], [{"op": "cancel"}])
        self.assertEqual([i["label"] for i in dm.build_menu(decision("choice_yes_no"))], ["Yes", "No"])
        d = decision("choice_count")
        d["options"]["choice"]["count"] = 2
        menu = dm.build_menu(d)
        menu = dm.build_menu(d, menu[3]["plan"]["sub"])
        self.assertEqual(menu[0]["ops"], [{"op": "choice", "picks": [3, 0]}])

    def test_a_choice_that_takes_no_pick_answers_nothing(self):
        d = decision("choice_count")
        d["options"]["choice"]["count"] = 0
        menu = dm.build_menu(d)
        self.assertEqual(ids(menu), ["choice:none"])
        self.assertEqual(menu[0]["ops"], [{"op": "choice", "picks": []}])
        self.assertEqual(dm.fallback_action(d), {"op": "choice", "picks": []})

    def test_damage_presets(self):
        d = decision("damage")
        menu = dm.build_menu(d)
        self.assertEqual(menu[0]["ops"], [{"op": "damage", "points": [["c9", 1], ["c12", 1]]}])
        self.assertIn([{"op": "damage", "points": [["c12", 2]]}], [i["ops"] for i in menu])
        d["view"]["presentation"]["rules"]["free_damage_assignment"] = False
        menu = dm.build_menu(d)
        self.assertNotIn("damage:all:c12", ids(menu))

    def test_the_opening(self):
        self.assertEqual(ids(dm.build_menu(decision("opening_order"))), ["order:play", "order:draw"])
        self.assertEqual(ids(dm.build_menu(decision("opening_keep"))), ["keep", "mulligan"])


class TargetsTest(unittest.TestCase):
    def test_an_open_announcement_is_a_target_sub_menu(self):
        d = decision("announce_multi")
        menu = dm.build_menu(d)
        self.assertEqual(ids(menu), ["target:you", "target:opp", "target:c31", "target:c34", "cancel"])
        menu = dm.build_menu(d, menu[1]["plan"]["sub"])
        self.assertEqual(ids(menu)[0], "target:done")
        self.assertNotIn("target:opp", ids(menu))
        done = menu[0]
        self.assertEqual(done["ops"], [{"op": "autopay", "excluded": [], "count": 1},
                                      {"op": "submit", "targets": [["t1", 0]]}])

    def test_another_target_leaves_out_an_earlier_slots_pick(self):
        d = decision("announce_multi")
        slot = d["options"]["announcement"]["slots"][0]
        slot["max"] = 1
        second = copy.deepcopy(slot)
        second["label"] = "another target"
        second["targets"] = [{"id": f"t{4 + i}", "label": t["label"]} for i, t in enumerate(slot["targets"])]
        d["options"]["announcement"]["slots"].append(second)
        refs = d["view"]["presentation"]["targets"]
        refs += [{"token": f"t{4 + i}", "ref": r["ref"]} for i, r in enumerate(refs[:4])]
        menu = dm.build_menu(d)
        pick = menu[ids(menu).index("target:c31")]
        menu = dm.build_menu(d, pick["plan"]["sub"])
        self.assertNotIn("target:c31", ids(menu))
        self.assertIn("target:c34", ids(menu))
        final = menu[ids(menu).index("target:opp")]
        self.assertEqual(final["ops"][-1], {"op": "submit", "targets": [["t2", 0], ["t5", 0]]})

    def test_divided_damage_is_split_evenly(self):
        self.assertEqual(dm.split(5, 2), [3, 2])
        self.assertEqual(dm.split(0, 2), [0, 0])
        d = decision("announce_multi")
        d["options"]["announcement"]["slots"][0]["divided"] = 3
        menu = dm.build_menu(d)
        menu = dm.build_menu(d, menu[ids(menu).index("target:opp")]["plan"]["sub"])
        menu = dm.build_menu(d, menu[ids(menu).index("target:c34")]["plan"]["sub"])
        done = menu[0]
        self.assertEqual(done["ops"][-1], {"op": "submit", "targets": [["t1", 2], ["t3", 1]]})


class PickTest(unittest.TestCase):
    def test_a_pick_is_an_index_an_id_or_an_object(self):
        menu = dm.build_menu(decision("attack"))
        self.assertEqual(dm.resolve_pick(menu, 1)["id"], "attack:all")
        self.assertEqual(dm.resolve_pick(menu, " 2 ")["id"], "attack:add:c2")
        self.assertEqual(dm.resolve_pick(menu, "attack:add:c7")["id"], "attack:add:c7")
        self.assertEqual(dm.resolve_pick(menu, {"pick": 0})["id"], "attack:none")
        self.assertEqual(dm.resolve_pick(menu, {"pick": "attack:all"})["id"], "attack:all")
        for bad in (9, -1, "nope", True, {"choice": 1}, 1.5):
            with self.assertRaises(ValueError):
                dm.resolve_pick(menu, bad)


class ObservationTest(unittest.TestCase):
    def test_the_deciding_seats_side_and_a_tenth_of_the_view(self):
        d = decision("block")
        obs = dm.encode_observation(d, journal=[{"text": "Wizard attacks."}])
        self.assertEqual(obs["mode"], "block")
        self.assertEqual(obs["me"]["life"], d["view"]["players"][0]["life"])
        self.assertEqual(obs["opp"]["life"], d["view"]["players"][1]["life"])
        self.assertEqual(obs["journal"], ["Wizard attacks."])
        self.assertTrue(any(c.get("attacking") for c in obs["opp"]["battlefield"]))
        self.assertEqual(len(obs["features"]), len(dm.FEATURES))
        self.assertTrue(all(-1.0 <= v <= 1.0 for v in obs["features"]))
        compact = len(json.dumps({k: v for k, v in obs.items() if k != "features"}))
        self.assertLess(compact, len(json.dumps(d["view"])) / 2)

    def test_seat_one_sees_itself_as_me_and_phased_out_permanents(self):
        d = decision("attack")
        d["seat"] = 1
        ghost = copy.deepcopy(d["view"]["players"][0]["battlefield"][0])
        ghost["id"] = "c77"
        d["view"]["players"][0]["phased_out"] = [ghost]
        obs = dm.encode_observation(d)
        self.assertEqual(obs["active"], "opp")
        self.assertEqual(obs["opp"]["phased_out"][0]["id"], "c77")
        self.assertTrue(obs["opp"]["phased_out"][0]["phased_out"])

    def test_the_feature_tables_are_the_vectors(self):
        self.assertEqual(len({n for n, _ in dm.FEATURES}), len(dm.FEATURES))
        contract = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
        self.assertIn(f"a fixed vector of {len(dm.FEATURES)} floats", contract)
        self.assertIn(f"one item's {len(dm.ITEM_FEATURES)} in", contract)
        for d in fixture()["decisions"].values():
            self.assertEqual(len(dm.feature_vector(d)), len(dm.FEATURES))
        menu = dm.build_menu(decision("block"))
        for item in menu:
            vector = dm.item_features(item)
            self.assertEqual(len(vector), len(dm.ITEM_FEATURES))
        self.assertEqual(dm.item_features(menu[1])[dm.KINDS.index("block_pair")], 1.0)
        self.assertEqual(dm.mana_value("{3}{W}{W}"), 5)
        self.assertEqual(dm.mana_value("{X}{R}"), 1)


class FakeReferee:
    """A scripted referee in process: `receive()` hands out queued records,
    `send(action)` logs the action and asks `answer(action)` for the next
    records."""

    def __init__(self, first: list, answer):
        self.queue = list(first)
        self.answer = answer
        self.sent: list = []
        self.n = 100

    def receive(self):
        return self.queue.pop(0) if self.queue else None

    def send(self, action: dict):
        self.sent.append(action)
        self.queue += self.answer(action, self)

    def renumber(self, d: dict) -> dict:
        d = copy.deepcopy(d)
        self.n += 1
        d["n"] = self.n
        d["view"]["journal"] = []
        return d


HELLO = {"type": "hello", "protocol": 1, "seats": [], "seed": 1}
RESULT = {"type": "result", "winner": 0, "turns": 9, "reason": "concluded", "refusals": 0}


class DriverTest(unittest.TestCase):
    def setUp(self):
        self.main = decision("priority_main")
        self.announce = announcement_for(self.main, "c1")

    def script(self, refuse_submit=False, ask_on_autopay=False):
        main, announce = self.main, self.announce
        question = decision("choice_yes_no")

        def answer(action, ref):
            op = action["op"]
            if op == "prepare":
                return [ref.renumber(announce)]
            if op == "cancel":
                return [ref.renumber(main)]
            if op == "autopay":
                return [ref.renumber(question if ask_on_autopay else announce)]
            if op == "choice":
                return [ref.renumber(announce)]
            if op == "submit":
                if refuse_submit:
                    return [{"type": "refused", "n": ref.n, "reason": "activate only once each turn",
                             "action": action}, ref.renumber(announce)]
                return [RESULT]
            return [RESULT]

        return FakeReferee([HELLO, self.main], answer)

    def driver(self, ref, **kw):
        driver = dm.Driver(ref.send, ref.receive, **kw)
        driver.start()
        return driver

    def test_a_flat_cast_is_probed_then_prepared_paid_and_submitted(self):
        ref = self.script()
        driver = self.driver(ref)
        menu = driver.menu()
        self.assertEqual([a["op"] for a in ref.sent], ["prepare", "cancel"])   # the probe
        self.assertIn("cast:c1->c12", ids(menu))
        driver.pick("cast:c1->c12")
        self.assertEqual([a["op"] for a in ref.sent[2:]], ["prepare", "autopay", "submit"])
        self.assertEqual(ref.sent[-1]["targets"], [["t1", 0]])
        self.assertEqual(ref.sent[-1]["seat"], 0)
        self.assertTrue(driver.done)
        self.assertEqual(driver.stats["refusals"], 0)
        self.assertEqual(driver.stats["probes"], 1)

    def test_a_refused_submit_is_cancelled_and_the_item_leaves_the_menu(self):
        ref = self.script(refuse_submit=True)
        driver = self.driver(ref)
        driver.menu()
        out = driver.pick("cast:c1->c2")
        self.assertEqual([a["op"] for a in ref.sent[2:]], ["prepare", "autopay", "submit", "cancel"])
        self.assertEqual(len(out["refused"]), 1)
        self.assertFalse(driver.done)
        self.assertFalse(driver.decision["options"].get("announcement"), "never left half-announced")
        left = ids(driver.menu())
        self.assertFalse([i for i in left if i == "cast:c1" or i.startswith("cast:c1->")])
        self.assertIn("cast:c10", left)

    def test_a_payment_question_goes_to_the_model_and_the_submit_follows(self):
        ref = self.script(ask_on_autopay=True)
        driver = self.driver(ref)
        driver.menu()
        driver.pick("cast:c1->c5")
        self.assertEqual(driver.decision["mode"], "choice")
        self.assertEqual(ids(driver.menu()), ["choice:0", "choice:1"])
        self.assertEqual(driver.observe()["mode"], "choice")
        driver.pick(0)
        self.assertEqual([a["op"] for a in ref.sent[-3:]], ["autopay", "choice", "submit"])
        self.assertEqual(ref.sent[-1]["targets"], [["t2", 0]])
        self.assertTrue(driver.done)

    def test_an_unreachable_announcement_is_withdrawn_with_nothing_paid(self):
        self.announce["options"]["draft"]["reachable"] = False
        ref = self.script()
        driver = self.driver(ref, probe=False)
        driver.pick("cast:c1")
        self.assertEqual([a["op"] for a in ref.sent], ["prepare", "cancel"])
        self.assertNotIn("cast:c1", ids(driver.menu()))

    def test_without_probes_the_cast_opens_the_target_sub_menu(self):
        ref = self.script()
        driver = self.driver(ref, probe=False)
        driver.pick("cast:c1")
        self.assertEqual(driver.observe()["mode"], "targets")
        self.assertEqual(ids(driver.menu()), ["target:c2", "target:c12", "target:c5", "cancel"])
        driver.pick("target:c5")
        self.assertEqual([a["op"] for a in ref.sent], ["prepare", "autopay", "submit"])
        self.assertTrue(driver.done)

    def test_a_menu_of_one_is_answered_alone_and_its_journal_kept(self):
        forced = decision("attack")
        forced["options"]["attack"]["attackable"] = []
        forced["view"]["journal"] = [{"serial": 5, "text": "Agent's declare attackers step."}]
        keep = decision("opening_keep")

        def answer(action, ref):
            return [keep] if action["op"] == "attack" else [RESULT]

        ref = FakeReferee([HELLO, forced], answer)
        driver = self.driver(ref)
        self.assertEqual(ref.sent, [{"op": "attack", "cards": [], "seat": 0}])
        self.assertEqual(driver.stats["forced"], 1)
        self.assertEqual(driver.observe()["journal"][0], "Agent's declare attackers step.")
        driver.pick("keep")
        self.assertEqual(driver.journal, [])

    def test_a_probe_is_reused_for_an_identical_state(self):
        main = self.main
        announce = self.announce

        def answer(action, ref):
            if action["op"] == "prepare":
                return [ref.renumber(announce)]
            if action["op"] == "cancel":
                return [ref.renumber(main)]
            if action["op"] == "play":
                return [ref.renumber(main)]   # the same state again (a stand-in)
            return [RESULT]

        ref = FakeReferee([HELLO, main], answer)
        driver = self.driver(ref)
        driver.menu()
        driver.pick("play:c7")
        driver.menu()
        self.assertEqual(driver.stats["probes"], 1)
        self.assertEqual(driver.stats["probe_hits"], 1)

    def test_sub_menu_picks_send_nothing_until_the_answer(self):
        attack = decision("attack")

        def answer(action, ref):
            return [RESULT]

        ref = FakeReferee([HELLO, attack], answer)
        driver = self.driver(ref)
        driver.pick("attack:add:c7")
        self.assertEqual(ref.sent, [])
        self.assertEqual(driver.observe()["selection"]["selected"], ["c7"])
        driver.pick("attack:declare")
        self.assertEqual(ref.sent, [{"op": "attack", "cards": ["c7"], "seat": 0}])

    def test_pass_until_stops_where_it_is_told(self):
        main = self.main

        def answer(action, ref):
            if action["op"] in ("prepare",):
                return [ref.renumber(self.announce)]
            if ref.n > 106:
                return [RESULT]
            return [ref.renumber(main)]

        ref = FakeReferee([HELLO, main], answer)
        driver = self.driver(ref, probe=False)
        out = driver.pick("pass", until=lambda d: "stop here" if d["n"] >= 104 else "")
        self.assertEqual(out["stop"], "stop here")
        self.assertEqual(out["passed"], 3)   # n 101, 102, 103 passed; 104 stops

    def test_the_end_of_the_line_is_an_error_not_a_hang(self):
        ref = FakeReferee([HELLO], lambda action, ref: [])
        driver = self.driver(ref)
        self.assertTrue(driver.done)
        self.assertEqual(driver.error["kind"], "eof")
        self.assertEqual(driver.menu(), [])
        self.assertEqual(driver.observe()["mode"], "finished")


class FakeGame:
    """The MCP server's `Game`, duck-typed for `attach_game`: `send`,
    `advance(timeout, render=False)`, `pending`, `result`, `error`,
    `memory`, `passed_journal`, `fresh` — over a FakeReferee."""

    def __init__(self, ref: FakeReferee):
        self.ref = ref
        self.pending = None
        self.result = None
        self.error = None
        self.memory: dict = {}
        self.passed_journal: list = []
        self.fresh = False
        self.advance(1)

    def send(self, action):
        if self.fresh and self.pending is not None:
            self.passed_journal += list(self.pending["view"].get("journal") or [])
        self.fresh = False
        self.pending = None
        self.ref.send(action)

    def advance(self, timeout, render=True):
        refused = []
        while True:
            record = self.ref.receive()
            if record is None:
                self.error = {"kind": "run", "message": "ended"}
                return {"refused": refused} if refused else {}
            if record.get("type") == "refused":
                refused.append(record)
            elif record.get("type") == "decision":
                self.pending, self.fresh = record, True
                return {"refused": refused} if refused else {}
            elif record.get("type") == "result":
                self.result = record
                return {"refused": refused} if refused else {}


class AttachGameTest(unittest.TestCase):
    """`attach_game` — the link referee_menu / referee_pick use inside the
    MCP server: one Driver a game, kept between calls."""

    def test_the_driver_lasts_between_calls_and_answers_through_the_game(self):
        attack = decision("attack")
        attack["view"]["journal"] = [{"serial": 3, "text": "Agent's combat."}]
        ref = FakeReferee([HELLO, attack], lambda action, ref: [RESULT])
        game = FakeGame(ref)
        game.passed_journal = [{"serial": 2, "text": "Wizard passes."}]
        driver = dm.attach_game(game, 5)
        state = dm.menu_state(driver)
        self.assertEqual(state["menu"][0], {"id": "attack:none", "label": "No attack"})
        self.assertEqual(state["obs"]["journal"], ["Wizard passes.", "Agent's combat."])
        self.assertEqual(game.passed_journal, [])
        driver.pick("attack:add:c2")
        again = dm.attach_game(game, 5)
        self.assertIs(again, driver)
        self.assertEqual(ids(again.menu()), ["attack:declare", "attack:add:c7"])
        again.pick("attack:declare")
        self.assertEqual(ref.sent, [{"op": "attack", "cards": ["c2"], "seat": 0}])
        self.assertTrue(again.done)
        self.assertEqual(dm.menu_state(again)["result"]["reason"], "concluded")

    def test_a_decision_answered_by_another_tool_is_taken_up_afresh(self):
        attack = decision("attack")
        block = decision("block")
        ref = FakeReferee([HELLO, attack], lambda action, ref: [block])
        game = FakeGame(ref)
        driver = dm.attach_game(game, 5)
        driver.pick("attack:add:c2")                 # a sub-menu step, nothing sent
        game.send({"op": "attack", "cards": []})     # referee_act answered meanwhile
        game.advance(5)
        again = dm.attach_game(game, 5)
        self.assertIsNone(again.sub)
        self.assertEqual(again.observe()["mode"], "block")
        self.assertEqual(ids(again.menu())[0], "block:none")


FAKE_DOOR = r'''#!/usr/bin/env python3
"""A fake shandalar.sh for tools/test_shandalar_decide.py: `referee` plays
a scripted duel from the fixture (order, keep, result) and logs what it
read; FAKE_DECIDE_MODE=refuse answers with the referee's refusal envelope."""
import json, os, sys
log = open(os.environ["FAKE_DECIDE_LOG"], "a")
log.write(json.dumps({"argv": sys.argv[1:]}) + "\n")
if os.environ.get("FAKE_DECIDE_MODE") == "refuse":
    print(json.dumps({"error": {"tool": "referee", "exit": 2, "kind": "deck",
                                "message": "deck file not found: 'nope.deck'"}}), flush=True)
    sys.exit(2)
fx = json.load(open(os.environ["FAKE_DECIDE_FIXTURE"]))["decisions"]
def out(record):
    print(json.dumps(record), flush=True)
out({"type": "hello", "protocol": 1, "seed": 4, "seats": []})
plan = [fx["opening_order"], fx["opening_keep"]]
out(plan.pop(0))
for line in sys.stdin:
    if not line.strip():
        continue
    action = json.loads(line)
    log.write(json.dumps(action) + "\n")
    log.flush()
    if not plan:
        break
    out(plan.pop(0))
out({"type": "result", "winner": 0, "turns": 1, "reason": "concluded", "decisions": 2, "refusals": 0,
     "seed": 4})
'''


class CommandLineTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="decide-cli-")
        self.addCleanup(self.tmp.cleanup)
        self.door = Path(self.tmp.name) / "shandalar.sh"
        self.door.write_text(FAKE_DOOR, encoding="utf-8")
        self.door.chmod(self.door.stat().st_mode | stat.S_IXUSR)
        self.log = Path(self.tmp.name) / "door.log"
        self.env = dict(os.environ, FAKE_DECIDE_LOG=str(self.log), FAKE_DECIDE_FIXTURE=str(FIXTURE),
                        SHANDALAR_NO_BANNER="1")

    def run_cli(self, args, stdin="", env=None):
        return subprocess.run([sys.executable, str(SCRIPT), "--door", str(self.door), *args],
                              input=stdin, capture_output=True, text=True, timeout=60,
                              env=env or self.env, cwd=self.tmp.name)

    def logged(self) -> list:
        return [json.loads(line) for line in self.log.read_text(encoding="utf-8").splitlines()]

    def test_help_and_version(self):
        done = subprocess.run([sys.executable, str(SCRIPT), "-h"], capture_output=True, text=True, timeout=60)
        self.assertEqual(done.returncode, 0)
        self.assertIn("usage:", done.stdout)
        self.assertIn(tool_banner.NO_BANNER_ENV, done.stdout)
        done = subprocess.run([sys.executable, str(SCRIPT), "--version"], capture_output=True, text=True,
                              timeout=60)
        self.assertEqual(done.returncode, 0)
        self.assertEqual(done.stdout.strip(),
                         "shandalar_decide.py — Shandalar %s" % tool_banner.project_version(ROOT))
        for glyph in "┌┐└┘├┤┬┴─│":
            self.assertNotIn(glyph, done.stdout)

    def test_describe_prints_every_field_without_a_referee(self):
        done = subprocess.run([sys.executable, str(SCRIPT), "--describe"], capture_output=True, text=True,
                              timeout=60)
        self.assertEqual(done.returncode, 0, done.stderr)
        table = json.loads(done.stdout)
        self.assertEqual([row["name"] for row in table["features"]], [n for n, _ in dm.FEATURES])
        self.assertEqual(len(table["item_features"]), len(dm.ITEM_FEATURES))
        self.assertEqual(table["kinds"], list(dm.KINDS))
        missing = subprocess.run([sys.executable, str(SCRIPT), "--deck-a", "a.deck"], capture_output=True,
                                 text=True, timeout=60)
        self.assertEqual(missing.returncode, 2)
        self.assertEqual(json.loads(missing.stdout)["error"]["flag"], "--deck-b")

    def test_the_json_lines_protocol(self):
        done = self.run_cli(["--deck-a", "a.deck", "--deck-b", "b.deck", "--seed", "4"],
                            stdin='99\n1\n"keep"\n')
        self.assertEqual(done.returncode, 0, done.stderr)
        lines = [json.loads(line) for line in done.stdout.splitlines()]
        first = lines[0]
        self.assertEqual(first["n"], 0)
        self.assertEqual(first["menu"], [{"id": "order:play", "label": "Play first"},
                                         {"id": "order:draw", "label": "Draw first"}])
        self.assertEqual(first["obs"]["mode"], "opening")
        self.assertIn("features", first["obs"])
        self.assertIn("error", lines[1])                          # 99 names no item
        self.assertEqual(lines[2]["menu"], first["menu"])         # the same decision again
        self.assertEqual(lines[3]["menu"][0]["id"], "keep")
        self.assertEqual(lines[-1]["result"]["reason"], "concluded")
        logged = self.logged()
        self.assertEqual(logged[0]["argv"][:3], ["referee", "--deck-a", "a.deck"])
        self.assertIn("--seed", logged[0]["argv"])
        self.assertEqual(logged[1], {"op": "order", "play": False, "seat": 0})
        self.assertEqual(logged[2], {"op": "keep", "seat": 0})

    def test_a_policy_plays_episodes_and_sums_them_up(self):
        done = self.run_cli(["--deck-a", "a.deck", "--deck-b", "b.deck", "--seed", "4",
                             "--policy", "first", "--episodes", "2", "--opponent", "magician"])
        self.assertEqual(done.returncode, 0, done.stderr)
        lines = [json.loads(line) for line in done.stdout.splitlines()]
        self.assertEqual([line.get("game") for line in lines[:2]], [1, 2])
        self.assertEqual([line["seed"] for line in lines[:2]], [4, 4])   # the fake's own seed
        summary = lines[-1]["summary"]
        self.assertEqual((summary["games"], summary["wins"], summary["refusals"]), (2, 2, 0))
        argvs = [row["argv"] for row in self.logged() if "argv" in row]
        self.assertEqual([a[a.index("--seed") + 1] for a in argvs], ["4", "5"])
        self.assertEqual(argvs[0][argvs[0].index("--seat-b") + 1], "magician")

    def test_the_referees_refusal_is_the_answer(self):
        env = dict(self.env, FAKE_DECIDE_MODE="refuse")
        done = self.run_cli(["--deck-a", "nope.deck", "--deck-b", "b.deck"], env=env)
        self.assertEqual(done.returncode, 2, done.stdout + done.stderr)
        envelope = json.loads(done.stdout.splitlines()[-1])
        self.assertEqual(envelope["error"]["kind"], "deck")

    def test_rules_reach_the_referee(self):
        done = self.run_cli(["--deck-a", "a.deck", "--deck-b", "b.deck", "--rules", "fifth",
                             "--policy", "first"])
        self.assertEqual(done.returncode, 0, done.stderr)
        argv = self.logged()[0]["argv"]
        self.assertEqual(argv[argv.index("--rules") + 1], "fifth")

    def test_bad_words_are_refused_before_a_referee_runs(self):
        with self.assertRaises(sd.RefereeError):
            sd.referee_argv("a", "b", opponent="dragon")
        self.assertEqual(sd.referee_argv("a", "b", "self", seat=1, seed=3, packs="8", rules="modern")[:6],
                         ["--deck-a", "a", "--deck-b", "b", "--seat-a", "agent"])
        done = self.run_cli(["--deck-a", "a.deck", "--deck-b", "b.deck", "--policy", "random",
                             "--episodes", "0"])
        self.assertEqual(done.returncode, 2)
        self.assertFalse(self.log.exists())


class PolicyTest(unittest.TestCase):
    def test_every_policy_answers_every_fixture(self):
        rng = random.Random(3)
        for d in fixture()["decisions"].values():
            menu = dm.public_menu(dm.build_menu(d, probes=probe_records(d) if dm.probe_actions(d) else None),
                                  rich=True)
            obs = dm.encode_observation(d)
            for name, policy in sd.POLICY.items():
                index = policy(obs, menu, rng)
                self.assertTrue(0 <= index < len(menu), name)

    def test_greedy_aims_harm_at_the_opponent_and_help_at_itself(self):
        d = decision("priority_main")
        menu = dm.public_menu(dm.build_menu(d, probes=probe_records(d)), rich=True)
        obs = dm.encode_observation(d)
        pick = menu[sd.policy_greedy(obs, menu, random.Random(1))]["id"]
        self.assertEqual(pick, "play:c7")
        no_land = [m for m in menu if not m["id"].startswith("play:")]
        pick = no_land[sd.policy_greedy(obs, no_land, random.Random(1))]["id"]
        self.assertIn(pick, ("cast:c10", "cast:c13"))   # the dearest creature, not a pump in main


class SystemOneTest(unittest.TestCase):
    """The typed-decision adaptor (Laya, Jev): the menu as one `choice`
    question over the compact state, the model's choice read back. No
    model is installed: a stand-in server answers like laya-serve."""

    def setUp(self):
        d = decision("priority_main")
        self.menu = dm.public_menu(dm.build_menu(d, probes=probe_records(d)), rich=True)
        self.obs = dm.encode_observation(d, journal=[{"text": "Turn 3"}])

    def test_the_request_is_the_compact_state_and_readable_options(self):
        request = sd.systemone_request(self.obs, self.menu, "jev-latest")
        self.assertEqual(request["model"], "jev-latest")
        self.assertNotIn("features", request["state"])
        self.assertNotIn("journal", request["state"])
        self.assertIn("hand", request["state"])
        question = request["questions"]["action"]
        self.assertEqual((question["type"], question["instructions"]), ("choice", sd.SYSTEMONE_QUESTION))
        self.assertEqual(len(question["criteria"]), len(self.menu))
        self.assertEqual(list(question["criteria"])[0], self.menu[0]["label"])
        self.assertNotIn("model", sd.systemone_request(self.obs, self.menu))

    def test_repeated_labels_stay_distinct_options(self):
        menu = [{"id": "a", "label": "Pass"}, {"id": "b", "label": "Pass"}, {"id": "c", "label": "Pass"}]
        names = list(sd.systemone_request({}, menu)["questions"]["action"]["criteria"])
        self.assertEqual(names, ["Pass", "Pass (2)", "Pass (3)"])

    def test_the_answer_names_the_pick(self):
        request = sd.systemone_request(self.obs, self.menu)
        names = list(request["questions"]["action"]["criteria"])
        self.assertEqual(sd.systemone_pick({"answers": {"action": {"choice": names[2]}}}, request), 2)
        odds = {name: 0.01 for name in names}
        odds[names[1]] = 0.9
        self.assertEqual(sd.systemone_pick({"answers": {"action": {"probabilities": odds}}}, request), 1)
        with self.assertRaises(ValueError):
            sd.systemone_pick({"answers": {"action": {"choice": "Concede the match"}}}, request)

    def test_the_policy_asks_a_server_like_laya_serve(self):
        import http.server
        import threading
        seen = {}

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                seen.update(path=self.path, auth=self.headers.get("Authorization"), body=body)
                names = list(body["questions"]["action"]["criteria"])
                reply = json.dumps({"answers": {"action": {"choice": names[-1], "confidence": 0.5}}}).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(reply)))
                self.end_headers()
                self.wfile.write(reply)

            def log_message(self, *args):
                pass

        server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            url = f"http://127.0.0.1:{server.server_address[1]}/v1/systemone"
            old = os.environ.pop("SYSTEMONE_API_KEY", None)
            try:
                os.environ["SYSTEMONE_API_KEY"] = "test-key"
                pick = sd.systemone_policy(url, "jev-latest")(self.obs, self.menu, random.Random(1))
            finally:
                os.environ.pop("SYSTEMONE_API_KEY", None)
                if old is not None:
                    os.environ["SYSTEMONE_API_KEY"] = old
        finally:
            server.shutdown()
            server.server_close()
        self.assertEqual(pick, len(self.menu) - 1)
        self.assertEqual(seen["path"], "/v1/systemone")
        self.assertEqual(seen["auth"], "Bearer test-key")
        self.assertEqual(seen["body"]["model"], "jev-latest")

    def test_systemone_needs_a_url(self):
        result = subprocess.run([sys.executable, str(SCRIPT), "--deck-a", "a.deck", "--deck-b", "b.deck",
                                 "--policy", "systemone"], capture_output=True, text=True, timeout=120,
                                env=dict(os.environ, SHANDALAR_NO_BANNER="1"))
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("--url", result.stdout)


class ReleaseTest(unittest.TestCase):
    def test_the_release_ships_both_tools(self):
        import package_release as pack
        for name in ("decision_menu.py", "shandalar_decide.py", "shandalar_mcp.py", "tool_banner.py"):
            self.assertIn(name, pack.TOOLS)
        files = pack.player_tool_files(ROOT)
        self.assertEqual(files["tools/shandalar_decide.py"], ROOT / "tools" / "shandalar_decide.py")
        self.assertEqual(files["tools/decision_menu.py"], ROOT / "tools" / "decision_menu.py")

    def test_a_staged_copy_answers_beside_the_modules_it_imports(self):
        import package_release as pack
        with tempfile.TemporaryDirectory(prefix="decide-stage-") as tmp:
            stage = Path(tmp) / "release"
            stage.mkdir()
            pack.stage_player_tools(stage, ROOT)
            done = subprocess.run([sys.executable, str(stage / "tools" / "shandalar_decide.py"), "--version"],
                                  capture_output=True, text=True, timeout=60, cwd=tmp)
            self.assertEqual(done.returncode, 0, done.stderr)
            self.assertTrue(done.stdout.startswith("shandalar_decide.py — Shandalar"))
            missing = subprocess.run([sys.executable, str(stage / "tools" / "shandalar_decide.py"),
                                      "--deck-a", "a", "--deck-b", "b"], capture_output=True, text=True,
                                     timeout=60, cwd=tmp)
            self.assertEqual(missing.returncode, 2)   # no door in a folder of tools alone
            self.assertIn("no shandalar.sh", json.loads(missing.stdout)["error"]["message"])


# --- the real referee ----------------------------------------------------------

PACK_8_DECK = """name: Decide Pack 8 Knights
4 Mtenda Herder
4 Femeref Knight
3 Zhalfirin Knight
3 Knight of Valor
2 Zhalfirin Commander
4 Suq'Ata Lancer
3 Searing Spear Askari
2 Burning Shield Askari
4 Agility
3 Jabari's Banner
1 Telim'Tor
3 Hearth Charm
13 Plains
11 Mountain
"""


def pack_8_zip() -> str | None:
    for spoken in (os.environ.get("SHANDALAR_PACK_8"), str(ROOT.parent / "shandalar-packs" / "Pack-8-Mirage-Block.zip")):
        if spoken and Path(spoken).is_file():
            return spoken
    return None


@unittest.skipUnless(LIVE, "SHANDALAR_DECIDE_LIVE=1 runs the real referee")
class LiveTest(unittest.TestCase):
    """Complete duels against the wizard through the real referee, with
    zero refusals: the menus offer only what the referee takes."""

    @classmethod
    def setUpClass(cls):
        profile = os.environ.get("SHANDALAR_TEST_DATA_HOME") or str(Path(tempfile.gettempdir()) / "shandalar-test-data")
        Path(profile).mkdir(parents=True, exist_ok=True)
        cls.env = dict(os.environ, XDG_DATA_HOME=profile)
        cls.tmp = tempfile.TemporaryDirectory(prefix="decide-live-")

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def duel(self, deck_a, deck_b, policy, seed, packs=None):
        with sd.Env(deck_a, deck_b, opponent="wizard", seed=seed, packs=packs, env=self.env) as env:
            line = sd.play(env, sd.POLICY[policy], random.Random(seed), seed)
            refused = list(env.driver.refused)
        self.assertEqual(line["reason"], "concluded", line)
        self.assertEqual(line["refusals"], 0, refused)
        self.assertEqual(line["referee_refusals"], 0, refused)
        self.assertGreater(line["decisions"], 0)
        return line

    def test_random_and_greedy_play_core_decks_to_the_end(self):
        for policy, seed in (("random", 3), ("greedy", 5)):
            with self.subTest(policy=policy):
                self.duel("decks/big_green.deck", "decks/white_knights.deck", policy, seed)
        self.duel("decks/mountain_artillery.deck", "decks/white_knights.deck", "greedy", 7)

    def test_random_and_greedy_play_a_pack_8_deck_to_the_end(self):
        zip_path = pack_8_zip()
        if zip_path is None:
            self.skipTest("no Pack-8-Mirage-Block.zip (SHANDALAR_PACK_8)")
        self.env["SHANDALAR_PACK_8"] = zip_path
        deck = Path(self.tmp.name) / "decide_p8_knights.deck"
        deck.write_text(PACK_8_DECK, encoding="utf-8")
        for policy, seed in (("random", 21), ("greedy", 23)):
            with self.subTest(policy=policy):
                self.duel(str(deck), "decks/white_knights.deck", policy, seed, packs="8")

    def test_the_json_lines_protocol_plays_a_duel(self):
        proc = subprocess.Popen([sys.executable, str(SCRIPT), "--deck-a", "decks/big_green.deck",
                                 "--deck-b", "decks/white_knights.deck", "--seed", "9", "--no-features"],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                text=True, env=self.env, cwd=str(ROOT))
        rng = random.Random(9)
        last = None
        try:
            for raw in proc.stdout:
                last = json.loads(raw)
                if "result" in last:
                    break
                self.assertNotIn("error", last)
                menu = last["menu"]
                pick = rng.randrange(len(menu))
                proc.stdin.write((json.dumps(menu[pick]["id"]) if pick % 2 else str(pick)) + "\n")
                proc.stdin.flush()
        finally:
            proc.stdin.close()
            proc.wait(timeout=120)
            proc.stdout.close()
            proc.stderr.close()
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(last["result"]["reason"], "concluded")
        self.assertEqual(last["summary"]["refusals"], 0)

    def test_a_fifth_rules_game_reports_its_rules_and_plays_to_the_end(self):
        with sd.Env("decks/big_green.deck", "decks/white_knights.deck", opponent="wizard", seed=17,
                    rules="fifth", env=self.env) as env:
            line = sd.play(env, sd.POLICY["greedy"], random.Random(17), 17)
            self.assertEqual(env.hello["rules"], "fifth")
            self.assertEqual(env.stats()["rules"], "fifth")
        self.assertEqual(line["rules"], "fifth")
        self.assertEqual(line["reason"], "concluded")
        self.assertEqual((line["refusals"], line["referee_refusals"]), (0, 0))

    def test_the_model_can_play_both_seats(self):
        with sd.Env("decks/big_green.deck", "decks/white_knights.deck", opponent="self", seed=13,
                    turns=6, env=self.env) as env:
            env.reset()
            seats = set()
            rng = random.Random(13)
            while not env.done:
                seats.add(env.decision["seat"])
                env.step(rng.randrange(len(env.menu())))
            self.assertEqual(seats, {0, 1})
            self.assertEqual(env.stats()["refusals"], 0)
            self.assertIn(env.result["reason"], ("concluded", "limit"))


if __name__ == "__main__":
    unittest.main()
