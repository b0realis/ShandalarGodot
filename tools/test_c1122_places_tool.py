#!/usr/bin/env python3
"""tools/adventure_plugin.py — the places campaign of 2026-11-22: the wider
vocabulary of a sites plugin (plugin API 3) in validate, walk, compat and
info; the commands that write a place without a JSON file being opened
(add-action, add-pane, add-flag, add-counter, add-foe, set-text, set-info,
remove-place); the ten recipes of add-place; the warnings validate gives a
plugin that loads but is not finished; the cheat sheet; and the four study
plugins, made with those commands.

The verdicts are the game's: every case of the corpus
(tools/plugin_fixtures/expected.json, the sites_api3_ cases among them) is
judged by the game's own loader in tests/unit/test_plugin_corpus.gd, the
recipes' places are two of its cases, and the study plugins are played in
the game by tests/unit/test_c1122_ptool.gd.

No Godot, no network. Run from the repo root:
    python3 tools/test_c1122_places_tool.py
"""
from __future__ import annotations

import html
import json
import re
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))
import adventure_plugin as ap  # noqa: E402
from test_adventure_plugin import FIXTURES, build_case, corpus, files_of, run_tool  # noqa: E402

PLUGINS = ROOT / "expanded_adventure"
STUDIES = {"Gamblers_Den": "gamblers_den", "Riddle_Stone": "riddle_stone",
           "Wandering_Collector": "wandering_collector", "Duelists_Ring": "duelists_ring"}
## The recipes, as the corpus holds them: two plugins of five places each
## (a sites plugin has at most eight places).
RECIPE_CASES = {"good_sites_api3_recipes_one": ["lore", "gift", "healer", "toll", "gambler"],
                "good_sites_api3_recipes_two": ["riddle", "collector", "duelist", "shop", "quest"],
                "good_sites_api3_recipes_three": ["traveler", "teacher"]}


def recipe_case(name: str, recipes: list) -> dict:
    """The corpus case of [recipes]: the corpus's sites plugin with each
    recipe's place laid into it, as add-place --recipe writes it (under a
    skin picture, since a case names no new picture files)."""
    sites, text = [], []
    flags, counters, foes, tasks = [], [], {}, {}
    for recipe in recipes:
        key = "p_" + recipe
        parts = ap.place_recipe(recipe, key, "The " + recipe.title(), ap.RECIPE_CARD.get(recipe, ""))
        sites.append({"path": ["sites", key], "value": {
            "name": "The " + recipe.title(), "where": ["mainland"], "picture": "visit_wiseman",
            "sprite": {"file": "art/corpus_sites_shrine_map.png", "width": 80}, "gap": 3, "panes": parts["panes"]}})
        text += [{"path": [k], "value": v} for k, v in parts["words"].items()]
        flags += parts["flags"]
        counters += parts["counters"]
        foes.update(parts["foes"])
        tasks.update(parts["tasks"])
    for part, value in (("flags", flags), ("counters", counters), ("foes", foes), ("tasks", tasks)):
        sites.append({"path": [part], "value": value})
    return {"name": name, "base": "good_sites",
            "edit": {"plugin.json": {"set": [{"path": ["api_version"], "value": 3}]},
                     "sites.json": {"set": sites}, "text.json": {"set": text}}, "valid": True, "reason": ""}


class Work(unittest.TestCase):
    """A sites plugin folder of the test's own: what new --kind sites writes."""

    def setUp(self):
        self.work = Path(tempfile.mkdtemp(prefix="plugin-c1122-"))
        self.folder = self.work / "Corpus_Sites"
        shutil.copytree(FIXTURES / "good_sites", self.folder)
        self.game = ap.find_game()

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def tool(self, *args, ok: bool = True):
        result = run_tool(*args, cwd=self.work)
        if ok:
            self.assertEqual(result.returncode, 0, "%s\n%s%s" % (args, result.stdout, result.stderr))
        return result

    def judged(self) -> dict:
        result = ap.judge(str(self.folder), self.game)
        self.assertTrue(result["valid"], result["problems"])
        return result

    def sites(self) -> dict:
        return json.loads((self.folder / "sites.json").read_text(encoding="utf-8"))

    def text(self) -> dict:
        return json.loads((self.folder / "text.json").read_text(encoding="utf-8"))

    def api(self) -> int:
        return json.loads((self.folder / "plugin.json").read_text(encoding="utf-8"))["api_version"]

    def snapshot(self) -> dict:
        return {rel: (self.folder / rel).read_bytes() for rel in files_of(self.folder)}

    def warnings(self) -> list:
        return self.judged()["warnings"]


# --------------------------------------------------------------------------

class CorpusOfApiThree(unittest.TestCase):
    def test_the_corpus_holds_a_good_and_a_bad_plugin_for_every_word(self):
        data = corpus()
        names = {case["name"] for case in data["cases"]}
        schema = ap.find_game().schema()
        words = schema["v3_words"]
        good = json.dumps(next(c for c in data["cases"] if c["name"] == "good_sites_api3_every_word"))
        for word in words["condition"] + words["effect"]:
            self.assertIn('{"%s": ' % word, good, word)
        for word in words["do"]:
            self.assertIn('"do": "%s"' % word, good, word)
        for word in words["file"] + words["pane"] + words["line"] + words["action"]:
            self.assertIn('"%s"' % word, good, word)
        for need in schema["types"]["sites_need"]["options"]:
            self.assertIn('{"%s": ' % need, good, need)
        for placeholder in ("food", "amulets", "day", "count", "foe", "life"):
            self.assertIn("{%s}" % placeholder, good)
        bad = [case for case in data["cases"] if case["name"].startswith("sites_api3_")]
        self.assertGreaterEqual(len(bad), 90)
        self.assertTrue(all(not case["valid"] and case["reason"] for case in bad))
        reasons = " ".join(case["reason"] for case in bad)
        # Each word of API 3 is refused at least once by name.
        for word in words["condition"] + words["effect"] + words["do"] + ["needs", "counters", "foes", "tasks",
                                                                         "one_of", "to", "foe", "win", "count",
                                                                         "cards", "stock", "id"]:
            self.assertRegex(reasons, r"[.\[\"]%s\b|\b%s " % (re.escape(word), re.escape(word)), word)
        for wanted in ("needs_api_3", "pane_id_needs_api_3", "last_pane_has_a_when", "pane_without_a_leave",
                       "every_pane_has_an_id", "roll_in_a_roll", "give_card_without_end", "task_used_without_a_place"):
            self.assertIn("sites_api3_" + wanted, names)

    def test_the_recipes_are_two_cases_of_the_corpus_so_the_game_reads_them(self):
        cases = {case["name"]: case for case in corpus()["cases"]}
        for name, recipes in RECIPE_CASES.items():
            self.assertEqual(cases.get(name), recipe_case(name, recipes),
                             "%s is not what add-place --recipe writes now: rebuild it (recipe_case)" % name)
        self.assertEqual(sorted(sum(RECIPE_CASES.values(), [])), sorted(ap.RECIPES))

    def test_the_api_gate_and_the_way_out_in_the_tools_own_words(self):
        work = Path(tempfile.mkdtemp(prefix="plugin-c1122-"))
        try:
            data = corpus()
            for name, begins in (("sites_api3_needs_api_3", "sites.json: sites.den.panes[0].actions[0].when[0].gold_below: "
                                                           "\"gold_below\" is a word of plugin API 3, and plugin.json "
                                                           "declares api_version 2."),
                                 ("sites_api3_last_pane_has_a_when", "sites.json: sites.den.panes[1].when: the last pane "
                                                                    "without an id must have no when"),
                                 ("sites_api3_pane_without_a_leave", "sites.json: sites.den.panes[0].actions: a pane needs "
                                                                    "an action that does \"leave\" and has no when")):
                case = next(c for c in data["cases"] if c["name"] == name)
                result = run_tool("validate", str(build_case(case, work, data["base_top"])))
                self.assertEqual(result.returncode, 1)
                self.assertTrue(result.stdout.startswith(begins), result.stdout)
        finally:
            shutil.rmtree(work, ignore_errors=True)


class Hints(Work):
    def test_a_sentence_where_a_key_belongs_is_explained_and_a_key_suggested(self):
        sites = self.sites()
        sites["sites"]["shrine"]["panes"][1]["lines"][0] = "Just a literal sentence here."
        (self.folder / "sites.json").write_text(json.dumps(sites), encoding="utf-8")
        result = self.tool("validate", "Corpus_Sites", ok=False)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout.splitlines()[0],
                         "sites.json.sites.shrine.panes[1].lines[0]: text.json has no Just a literal sentence here..",
                         "the game's own reason stands first")
        self.assertIn("holds a sentence, and a line holds a text key", result.stderr)
        self.assertIn('like "shrine.line1"', result.stderr)
        self.assertIn("set-text FOLDER shrine.line1", result.stderr)

    def test_a_mistyped_key_and_a_mistyped_card_get_their_nearest_names(self):
        sites = self.sites()
        sites["sites"]["shrine"]["panes"][1]["lines"][0] = "shrine.intor"
        sites["dungeons"] = {"vault": {"name": "V", "cards": ["Lightning Blot", "Thallid"]}}
        (self.folder / "sites.json").write_text(json.dumps(sites), encoding="utf-8")
        result = self.tool("validate", "Corpus_Sites", ok=False)
        self.assertIn("text.json's nearest keys to shrine.intor: shrine.intro", result.stderr)
        self.assertIn("the nearest card names to Lightning Blot: Lightning Bolt", result.stderr)
        self.assertIn("Thallid is a card of pack-2", result.stderr)
        self.assertIn("is not a card of the base game or of a required pack (none).", result.stdout)

    def test_new_names_the_next_commands_and_quotes_a_path_with_a_space(self):
        result = self.tool("new", "My Places", "--id", "my_places", "--name", "My Places", "--kind", "sites")
        for command in ("add-place 'My Places' --list-recipes", "add-place 'My Places' --id inn", "set-text 'My Places'",
                        "walk 'My Places'", "art 'My Places'", "validate 'My Places'", "export 'My Places' --out dist"):
            self.assertIn("python3 tools/adventure_plugin.py " + command, result.stdout)
        island = self.tool("new", "An Isle", "--id", "an_isle", "--name", "An Isle")
        self.assertIn("validate 'An Isle'", island.stdout)
        self.assertNotIn("add-place", island.stdout)


class Warnings(Work):
    def test_what_new_writes_warns_of_its_stand_ins_and_still_loads(self):
        result = self.tool("validate", "Corpus_Sites")
        lines = result.stdout.splitlines()
        self.assertEqual(lines[-2], "Corpus_Sites: valid (plugin corpus_sites 0.1.0).")
        self.assertEqual(lines[-1], "3 warnings: the game loads the plugin as it is; look at them before you share it.")
        self.assertEqual([line.split(":")[1].strip() for line in lines[:3]], ["plugin.json", "plugin.json", "art"])
        self.assertIn("warning: plugin.json: license still holds the tool's stand-in words", result.stdout)
        self.assertIn("2 pictures are the tool's stand-ins to paint over: art/corpus_sites_shrine.png, "
                      "art/corpus_sites_shrine_map.png", result.stdout)
        report = json.loads(self.tool("validate", "Corpus_Sites", "--json").stdout)
        self.assertEqual((report["valid"], len(report["warnings"])), (True, 3))
        self.assertEqual(self.tool("export", "Corpus_Sites", "--out", "dist").returncode, 0, "a warning never refuses")

    def test_the_shipped_and_the_study_plugins_have_no_warnings(self):
        for folder in ["Old_Adventurers_Hut", "Conjuration_Wizard_Guild"] + list(STUDIES):
            with self.subTest(plugin=folder):
                result = ap.judge(str(PLUGINS / folder), self.game)
                self.assertTrue(result["valid"], result["problems"])
                self.assertEqual(result["warnings"], [])

    def test_stand_in_words_unused_things_and_a_dungeon_nothing_raises(self):
        self.tool("add-place", "Corpus_Sites", "--id", "stall", "--name", "The Stall")
        self.tool("add-flag", "Corpus_Sites", "seen")
        self.tool("add-counter", "Corpus_Sites", "visits")
        self.tool("add-dungeon", "Corpus_Sites", "--id", "pit", "--name", "The Pit", "--cards", "Swamp")
        self.tool("set-text", "Corpus_Sites", "stall.extra", "Nobody says this.")
        said = "\n".join(self.warnings())
        for wanted in ("text.json: stall.intro still holds the tool's stand-in words (\"Write here...\"): write your "
                       "own (set-text stall.intro \"...\").",
                       "sites.json: the flag seen is never used.", "sites.json: the counter visits is never used.",
                       "sites.json: no action raises the dungeon pit", "text.json: stall.extra is used nowhere in sites.json."):
            self.assertIn(wanted, said)
        self.tool("add-action", "Corpus_Sites", "--place", "stall", "--id", "look", "--effect", "set_flag=seen",
                  "--label", "Look")
        self.assertIn("sites.json: the flag seen is set, but no when reads it.", self.warnings())

    def test_placeholders_that_cannot_be_filled_where_they_stand(self):
        self.tool("set-text", "Corpus_Sites", "shrine.intro", "The bowl asks {price} gold; {card} and {foe} wait; {town}.")
        said = "\n".join(self.warnings())
        self.assertIn("text.json: shrine.intro: {price} cannot be filled at sites.shrine.panes[0].lines (and 1 more): "
                      "{price} is filled in the label, the result and the journal lines of an action with prices", said)
        self.assertIn("text.json: shrine.intro: {card} cannot be filled at", said)
        self.assertIn("text.json: shrine.intro: {foe} cannot be filled at", said)
        self.assertIn("text.json: shrine.intro: {town} is filled in an island plugin's texts only", said)
        self.assertNotIn("shrine.bless", said, "{price} and {uses_left} belong in a priced action's label")
        self.assertNotIn("{dungeon}", said)

    def test_dungeon_and_count_with_nothing_to_say_which(self):
        for key in ("cellar", "attic"):
            self.tool("add-dungeon", "Corpus_Sites", "--id", key, "--name", "The " + key.title(), "--cards", "Swamp",
                      "--place", "shrine", "--price", "10")
        self.tool("add-place", "Corpus_Sites", "--id", "post", "--name", "The Post", "--service", "none")
        self.tool("set-text", "Corpus_Sites", "post.intro", "A signpost: {dungeon}, that way.")
        said = "\n".join(self.warnings())
        self.assertIn("text.json: post.intro: {dungeon} at sites.post.panes[0].lines is the plugin's first dungeon "
                      "(cellar): nothing there says which of its dungeons is meant.", said)
        self.tool("set-text", "Corpus_Sites", "cellar.open", "{dungeon} waits.")
        self.tool("set-text", "Corpus_Sites", "shrine.spent", "{dungeon} is all that is left to ask about.")
        said = "\n".join(self.warnings())
        self.assertNotIn("cellar.open", said, "its pane asks about the cellar")
        self.assertNotIn("shrine.spent", said, "its pane holds a button that raises one")
        self.tool("set-text", "Corpus_Sites", "post.intro", "A signpost: {count} roads meet here.")
        self.assertIn("text.json: post.intro: {count} cannot be filled at sites.post.panes[0].lines",
                      "\n".join(self.warnings()), "the plugin has no counter at all")

    def test_a_free_actions_label_gold_without_end_and_a_roll_that_pays(self):
        self.tool("add-action", "Corpus_Sites", "--place", "shrine", "--id", "alms", "--effect", "gold=25",
                  "--label", "Take alms ({price} gold, {uses_left} left)")
        said = "\n".join(self.warnings())
        self.assertIn("text.json: shrine.alms: {uses_left} in the label of sites.shrine.panes[1].actions[1], which has "
                      "no prices: a free action's label shows nothing there (\"( left)\").", said)
        self.assertIn("text.json: shrine.alms: {price} in the label of", said)
        self.assertIn("sites.json: sites.shrine.panes[1].actions[1] gives 25 gold each time, has no prices and no "
                      "needs, and nothing in its when ends it", said)
        self.tool("add-flag", "Corpus_Sites", "paid")
        self.tool("add-action", "Corpus_Sites", "--place", "shrine", "--id", "once", "--effect", "gold=25",
                  "--effect", "set_flag=paid", "--when", "not_flag=paid", "--label", "Take it once")
        self.assertNotIn("actions[2] gives", "\n".join(self.warnings()), "a not_flag ends it")
        self.tool("add-action", "Corpus_Sites", "--place", "shrine", "--id", "dice", "--prices", "10,10",
                  "--outcome", "1 | gold=100 | Won.", "--outcome", "1 |  | Lost.")
        self.assertIn("its roll pays 50 gold on average and its cheapest price is 10", "\n".join(self.warnings()))

    def test_a_long_pane_a_shadowed_pane_and_a_pane_no_talk_opens(self):
        sites = self.sites()
        shrine = sites["sites"]["shrine"]
        shrine["panes"][1]["lines"] = ["shrine.intro"] * 11
        shrine["panes"].insert(2, {"when": [{"gold_at_least": 5}], "lines": ["shrine.offer"],
                                   "actions": [{"id": "leave", "do": "leave", "label": "shrine.leave"}]})
        shrine["panes"].append(dict(shrine["panes"][2], when=[]))
        shrine["panes"].append({"id": "attic", "lines": ["shrine.offer"],
                                "actions": [{"id": "leave", "do": "leave", "label": "shrine.leave"}]})
        (self.folder / "sites.json").write_text(json.dumps(sites), encoding="utf-8")
        (self.folder / "plugin.json").write_text((self.folder / "plugin.json").read_text(encoding="utf-8")
                                                 .replace('"api_version": 2', '"api_version": 3'), encoding="utf-8")
        said = "\n".join(self.warnings())
        self.assertIn("sites.json: sites.shrine.panes[1] is long (11 lines", said)
        self.assertIn("sites.json: sites.shrine.panes[2] is never shown: a pane before it has no when", said)
        self.assertIn("sites.json: sites.shrine.panes[4] (id attic) is never shown: no talk action leads to it", said)

    def test_a_once_paid_dungeon_on_both_lands_warns_under_api_two_only(self):
        self.tool("add-dungeon", "Corpus_Sites", "--id", "pit", "--name", "The Pit", "--cards", "Swamp", "--place",
                  "shrine", "--price", "100")
        self.assertEqual(self.api(), 2)
        said = "\n".join(self.warnings())
        self.assertIn("raises the dungeon pit for a price at a place that stands on the mainland and on islands", said)
        self.assertIn("a game from before plugin API 3 counts it once for all lands", said)
        self.tool("add-counter", "Corpus_Sites", "n")
        self.assertEqual(self.api(), 3)
        self.assertNotIn("raises the dungeon pit", "\n".join(self.warnings()), "only a game with the fix reads it")
        # One hero on both lands: each land sells its own (finding 1.1).
        data = self.judged()["data"]
        hero = ap.walk_hero(data, 5000)
        first = ap.walk_site(data, "shrine", 5000, "mainland", None, hero)
        second = ap.walk_site(data, "shrine", 5000, "island", None, hero)
        self.assertEqual(first["steps"][-1]["state"]["dungeons"], {"pit": "cleared"})
        self.assertEqual(second["steps"][-1]["state"]["dungeons"], {"pit": "cleared"})
        self.assertEqual(hero.uses["shrine.pit@mainland"], 1)
        self.assertEqual(hero.uses["shrine.pit@island"], 1)
        self.assertEqual(hero.uses["shrine.bless"], 3, "the blessing is one count for both lands")


class EditCommands(Work):
    def test_add_place_free_and_the_wording(self):
        free = self.tool("add-place", "Corpus_Sites", "--id", "spring", "--name", "The Spring", "--free")
        self.assertIn("an effects service, free;", free.stdout)
        action = ap._site_actions(self.judged()["data"]["sites"]["sites"]["spring"])["service"]
        self.assertEqual(action["prices"], [])
        self.assertEqual(len(self.sites()["sites"]["spring"]["panes"]), 1, "never used up: no pane for it")
        self.assertEqual(self.text()["spring.pay"], "Use the service")
        priced = self.tool("add-place", "Corpus_Sites", "--id", "stall", "--name", "The Stall")
        self.assertIn("an effects service for 100 gold;", priced.stdout)
        self.assertNotIn("a effects", priced.stdout)
        copy = self.tool("add-place", "Corpus_Sites", "--id", "tower", "--name", "The Tower", "--service", "copy", "--free")
        self.assertIn("a copy service, free;", copy.stdout)
        run = ap.walk_site(self.judged()["data"], "spring", 0)
        self.assertEqual(run["steps"][-1]["state"]["uses"], {"spring.service": 2}, "free, pressed twice by a walk")
        for args, wanted in ((["--free", "--prices", "5"], "--prices and --free"),
                             (["--service", "none", "--free"], "--prices needs a service"),
                             (["--recipe", "lore", "--service", "copy"], "--recipe and --service"),
                             (["--recipe", "lore", "--free"], "belong to --service"),
                             (["--recipe", "lore", "--card", "Swamp"], "--card belongs to the recipes"),
                             (["--recipe", "lore", "--color", "red"], "--color belongs to the recipe toll")):
            refused = self.tool("add-place", "Corpus_Sites", "--id", "x", "--name", "X", *args, ok=False)
            self.assertEqual(refused.returncode, 2, args)
            self.assertIn(wanted, refused.stderr)

    def test_add_dungeon_at_a_place_with_a_service_keeps_both_buttons(self):
        """Finding 1.2: the dungeon's panes hid the service, and the
        service's used-up pane hid the dungeon's button."""
        self.tool("add-place", "Corpus_Sites", "--id", "gambler", "--name", "The Gambler", "--prices", "50")
        done = self.tool("add-dungeon", "Corpus_Sites", "--id", "cave", "--name", "The Cave", "--cards", "Swamp",
                         "--place", "gambler", "--action", "pay")
        self.assertIn("the button stands in 1 more pane of the place, so a service used up does not hide it", done.stdout)
        self.assertIn("each with the place's other button (service)", done.stdout)
        panes = self.sites()["sites"]["gambler"]["panes"]
        self.assertEqual([[a["id"] for a in pane["actions"]] for pane in panes],
                         [["service", "leave"], ["service", "leave"], ["pay", "leave"], ["service", "pay", "leave"]])
        walked = self.tool("walk", "Corpus_Sites", "--site", "gambler")
        self.assertIn("Every pane was shown and every button pressed.", walked.stdout)
        for order in ("pay,clear,service", "service,pay,clear"):
            run = ap.walk_site(self.judged()["data"], "gambler", 5000, press=order.split(","))
            self.assertEqual(run["steps"][-1]["state"]["uses"], {"gambler.service": 1, "gambler.pay@mainland": 1}, order)
            self.assertEqual(run["steps"][-1]["state"]["gold"], 5000 - 50 - 1000)
        # Nothing is paid for a dungeon that is open already (finding 1.7).
        self.tool("add-action", "Corpus_Sites", "--place", "gambler", "--pane", "all", "--id", "map", "--prices", "10,10",
                  "--effect", "spawn_dungeon=cave", "--label", "Buy the map again ({price} gold)")
        hero = ap.walk_hero(self.judged()["data"], 5000)
        self.assertEqual(hero.press("gambler", "map")["paid"], 10)
        again = hero.press("gambler", "map")
        self.assertEqual((again["refused"], again["paid"], hero.gold),
                         ("The Cave still waits for you; there is nothing new to tell.", 0, 4990))
        self.assertFalse(next(b for b in hero.describe("gambler")["buttons"] if b["id"] == "map")["ready"])
        hero.dungeons["cave"] = "cleared"
        self.assertEqual(hero.press("gambler", "map")["paid"], 10, "cleared: it may be raised again")

    def test_add_action_writes_every_kind_of_word_and_sets_api_three_by_itself(self):
        plain = self.tool("add-action", "Corpus_Sites", "--place", "shrine", "--id", "rest", "--effect", "food=2",
                          "--label", "Rest a while", "--result", "You rest.")
        self.assertNotIn("api_version", plain.stdout)
        self.assertEqual(self.api(), 2, "nothing of API 3 yet")
        self.assertIn("Added the action rest (effects) to the place shrine, in pane 1: free, never used up.", plain.stdout)
        self.assertIn("walk Corpus_Sites --site shrine", plain.stdout)
        self.tool("add-flag", "Corpus_Sites", "told")
        self.tool("add-dungeon", "Corpus_Sites", "--id", "vault", "--name", "The Vault", "--cards", "Swamp")
        counter = self.tool("add-counter", "Corpus_Sites", "wins")
        self.assertIn("plugin.json: api_version is now 3, because the plugin now uses counters", counter.stdout)
        self.assertEqual(self.api(), 3)
        done = self.tool(
            "add-action", "Corpus_Sites", "--place", "shrine", "--id", "rite", "--prices", "5,10",
            "--when", "not_flag=told | gold_at_least=5 | counter=wins:2-9",
            "--when", "has_card=Lightning Bolt:2", "--when", "amulets=red:1", "--when", "hero_color=red",
            "--when", "owns_magic=Dwarven Pick", "--when", "food_at_least=1", "--when", "gold_below=900",
            "--when", "day_at_least=3", "--when", "wizards_defeated=1", "--when", "at_peace=false",
            "--when", "difficulty=0-2", "--when", "plugin_on=old_hut", "--when", "site_used=shrine.bless:1",
            "--when", "gift_waiting=false", "--when", "used=bless:1-3", "--when", "dungeon=vault:none",
            "--needs", "card=Lightning Bolt", "--needs", "amulets=any:2", "--needs", "food=1",
            "--effect", "gold=-5", "--effect", "food=+3", "--effect", "set_flag=told", "--effect", "clear_flag=told",
            "--effect", "counter=wins+1", "--effect", "counter=wins:0", "--effect", "amulet=red:2",
            "--effect", "give_card=Llanowar Elves", "--effect", "next_duel=first_move",
            "--effect", "spawn_dungeon=vault", "--effect", "reveal_map=dungeon:vault:3",
            "--effect", "log_clue=A clue, {hero}.", "--effect", "log_event=Done at the shrine.",
            "--outcome", "2 | gold=10; counter=wins-1 | The rite goes well.", "--outcome", "1 |  | ",
            "--label", "Hold the rite ({price} gold)", "--result", "The rite is held.")
        self.assertIn("for 5, 10 gold", done.stdout)
        action = ap._site_actions(self.sites()["sites"]["shrine"])["rite"]
        self.assertEqual(action["when"], [
            {"any": [{"not_flag": "told"}, {"gold_at_least": 5}, {"counter": {"name": "wins", "min": 2, "max": 9}}]},
            {"has_card": {"card": "Lightning Bolt", "min": 2}}, {"amulets": {"color": "red", "min": 1}}, {"hero_color": "red"},
            {"owns_magic": "Dwarven Pick"}, {"food_at_least": 1}, {"gold_below": 900}, {"day_at_least": 3},
            {"wizards_defeated": 1}, {"at_peace": False}, {"difficulty": {"min": 0, "max": 2}}, {"plugin_on": "old_hut"},
            {"site_used": {"site": "shrine", "action": "bless", "min": 1}}, {"gift_waiting": False},
            {"used": {"action": "bless", "min": 1, "max": 3}}, {"dungeon": {"dungeon": "vault", "state": "none"}}])
        self.tool("add-action", "Corpus_Sites", "--place", "shrine", "--id", "nod", "--when", "flag=told",
                  "--when", "on_mainland=true", "--when", "used_up=bless", "--when", "counter=wins", "--label", "Nod")
        self.assertEqual(ap._site_actions(self.sites()["sites"]["shrine"])["nod"]["when"],
                         [{"flag": "told"}, {"on_mainland": True}, {"used_up": "bless"}, {"counter": {"name": "wins", "min": 1}}])
        self.assertEqual(action["needs"], [{"card": "Lightning Bolt"}, {"amulets": {"color": "any", "count": 2}}, {"food": 1}])
        self.assertEqual(action["effects"], [
            {"gold": -5}, {"food": 3}, {"set_flag": "told"}, {"clear_flag": "told"},
            {"counter": {"name": "wins", "add": 1}}, {"counter": {"name": "wins", "set": 0}},
            {"amulet": {"color": "red", "count": 2}}, {"give_card": "Llanowar Elves"}, {"next_duel": {"first_move": True}},
            {"spawn_dungeon": "vault"}, {"reveal_map": {"around": "dungeon:vault", "radius": 3}},
            {"log_clue": {"text": "shrine.rite_clue"}}, {"log_event": {"event": "shrine", "text": "shrine.rite_log"}},
            {"roll": {"outcomes": [{"weight": 2, "effects": [{"gold": 10}, {"counter": {"name": "wins", "add": -1}}],
                                    "result": ["shrine.rite_roll1"]}, {"weight": 1, "effects": []}]}}])
        text = self.text()
        self.assertEqual((text["shrine.rite"], text["shrine.rite_done"], text["shrine.rite_clue"], text["shrine.rite_roll1"]),
                         ("Hold the rite ({price} gold)", "The rite is held.", "A clue, {hero}.", "The rite goes well."))
        self.assertEqual([a["id"] for a in self.sites()["sites"]["shrine"]["panes"][1]["actions"]],
                         ["bless", "rest", "rite", "nod", "leave"], "before the Leave, in its place's own pane")
        self.judged()

    def test_add_action_talk_duel_and_trades_and_add_pane_add_foe(self):
        pane = self.tool("add-pane", "Corpus_Sites", "--place", "shrine", "--id", "niche", "--title", "The niche",
                         "--line", "A niche behind the lantern.", "--line", "Something was kept here once.")
        self.assertIn("Added pane 2 to the place shrine, id niche: 2 lines (shrine.niche_line*), and its Leave.", pane.stdout)
        self.assertIn("--do talk --to niche", pane.stdout)
        self.assertEqual(self.api(), 3)
        self.tool("add-action", "Corpus_Sites", "--place", "shrine", "--id", "look", "--do", "talk", "--to", "niche",
                  "--label", "Look behind the lantern")
        when = self.tool("add-pane", "Corpus_Sites", "--place", "shrine", "--when", "gold_below=5",
                         "--line", "You are too poor even for a shrine.")
        self.assertIn("Added pane 1 to the place shrine, shown while its when holds", when.stdout)
        panes = self.sites()["sites"]["shrine"]["panes"]
        self.assertEqual([("id" in p, bool(p.get("when"))) for p in panes],
                         [(False, True), (False, True), (False, False), (True, False)],
                         "a pane with a when goes before the place's own; a named one last")
        self.assertTrue(all(any(a["do"] == "leave" for a in p["actions"]) for p in panes))
        deck = self.work / "deck.txt"
        deck.write_text("# a small red deck\n10 Mountain\n4x Lightning Bolt\nGray Ogre\n\n// done\n", encoding="utf-8")
        foe = self.tool("add-foe", "Corpus_Sites", "--id", "guard", "--name", "The Shrine Guard", "--life", "12",
                        "--deck", str(deck), "--deck-name", "Guard Duty")
        self.assertIn("Added the foe guard (The Shrine Guard) to Corpus_Sites: 12 life, a deck of 15 cards (3 different)", foe.stdout)
        self.assertEqual(self.sites()["foes"]["guard"], {"name": "The Shrine Guard", "life": 12, "face": 3,
                                                         "deck": {"Mountain": 10, "Lightning Bolt": 4, "Gray Ogre": 1},
                                                         "deck_name": "Guard Duty"})
        again = self.tool("add-foe", "Corpus_Sites", "--id", "guard", "--name", "X", "--deck", str(deck), ok=False)
        self.assertIn("already has a foe guard (--replace", again.stderr)
        self.assertIn("Replaced the foe guard (The Old Guard) of Corpus_Sites",
                      self.tool("add-foe", "Corpus_Sites", "--id", "guard", "--name", "The Old Guard", "--deck", str(deck),
                                "--replace").stdout)
        self.tool("add-counter", "Corpus_Sites", "wins")
        self.tool("add-action", "Corpus_Sites", "--place", "shrine", "--id", "duel", "--do", "duel", "--foe", "guard",
                  "--prices", "30", "--count", "win", "--win-effect", "gold=80", "--win-effect", "counter=wins+1",
                  "--win", "The guard pays up.", "--lose", "The guard keeps your gold.", "--label", "Fight {foe} ({life} life)")
        self.tool("add-action", "Corpus_Sites", "--place", "shrine", "--id", "buy", "--do", "buy", "--stock", "1",
                  "--cards", "Lightning Bolt=120; Gray Ogre=20")
        self.tool("add-action", "Corpus_Sites", "--place", "shrine", "--id", "sell", "--do", "sell", "--pane", "niche",
                  "--cards", "Mountain=3", "--label", "Sell a Mountain")
        self.tool("add-action", "Corpus_Sites", "--place", "shrine", "--id", "copy", "--do", "copy", "--prices", "9",
                  "--pane", "all")
        actions = ap._site_actions(self.sites()["sites"]["shrine"])
        self.assertEqual(actions["duel"], {"id": "duel", "do": "duel", "label": "shrine.duel", "prices": [30],
                                           "foe": "guard", "win": {"effects": [{"gold": 80}, {"counter": {"name": "wins", "add": 1}}],
                                                                   "result": ["shrine.duel_won"]},
                                           "lose": {"result": ["shrine.duel_lost"]}, "count": "win"})
        self.assertEqual(actions["buy"], {"id": "buy", "do": "buy_card", "cards": {"Lightning Bolt": 120, "Gray Ogre": 20}, "stock": 1})
        panes = self.sites()["sites"]["shrine"]["panes"]
        self.assertEqual([a["id"] for a in panes[3]["actions"]], ["sell", "leave"])
        self.assertEqual([("copy" in [a["id"] for a in p["actions"]]) for p in panes], [True, True, True, False],
                         "--pane all: every pane without an id")
        data = self.judged()["data"]
        hero = ap.walk_hero(data, 1000, {"cards": ["Mountain"], "outcome": "win"})
        run = ap.walk_site(data, "shrine", 1000, "mainland", None, hero, ["look", "sell", "leave", "duel", "buy", "buy", "buy"])
        presses = [s for s in run["steps"] if s["kind"] == "press"]
        self.assertEqual([(p["action"], p["refused"] != "") for p in presses],
                         [("look", False), ("sell", False), ("duel", False), ("buy", False), ("buy", False), ("buy", True)])
        self.assertTrue(presses[0]["plain"], "a plain talk pays and counts nothing")
        self.assertEqual((presses[1]["earned"], presses[1]["traded"]), (3, "Mountain"))
        self.assertEqual((presses[2]["duel"], presses[2]["lines"]), ("won", ["The guard pays up."]))
        self.assertEqual(presses[5]["refused"], "Nothing here is for sale to you now.", "one of each in stock")
        self.assertEqual(hero.gold, 1000 + 3 - 30 + 80 - 120 - 20)
        self.assertEqual(run["steps"][-1]["state"]["counters"], {"wins": 1})

    def test_the_edit_commands_refuse_in_one_line_and_change_nothing(self):
        before = self.snapshot()
        deck = self.work / "deck.txt"
        deck.write_text("4 Lightning Blot\n", encoding="utf-8")
        empty = self.work / "empty.txt"
        empty.write_text("# nothing\n", encoding="utf-8")
        for args, code, wanted in (
                (["add-action", "Corpus_Sites", "--place", "tower", "--id", "x"], 2, "has no place tower (its places: shrine)"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "bless"], 2, "already has an action bless"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "Bad"], 2, "--id must be 1 to 32"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "x", "--prices", "5", "--free"], 2, "--prices and --free"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "x", "--when", "weather=fine"], 2, "no such condition"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "x", "--when", "gold_at_least=lots"], 2, "takes a whole number"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "x", "--effect", "summon=home"], 2, "no such effect"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "x", "--effect", "counter=wins"], 2, "NAME+N, NAME-N or NAME:N"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "x", "--needs", "gold=5"], 2, "a need is card=NAME"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "x", "--outcome", "gold=5"], 2, "WEIGHT | EFFECTS | WORDS"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "x", "--do", "talk"], 2, "--do talk needs --to"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "x", "--to", "niche"], 2, "--to belongs to --do talk"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "x", "--do", "duel"], 2, "--do duel needs --foe"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "x", "--win", "Yes"], 2, "belong to --do duel"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "x", "--do", "buy"], 2, "needs --cards"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "x", "--do", "buy", "--cards", "Bolt"], 2, "cards and prices joined by ;"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "x", "--stock", "2"], 2, "belong to --do buy and --do sell"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "x", "--pane", "7"], 2, "has no such pane"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "x", "--effect", "set_flag=nope"], 1,
                 "sites.json: sites.shrine.panes[1].actions[1].effects[0].set_flag: no flag nope in sites.json flags."),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "x", "--effect", "give_card=Swamp"], 1,
                 "a card is given without end"),
                (["add-action", "Corpus_Sites", "--place", "shrine", "--id", "x", "--do", "talk", "--to", "nowhere"], 1,
                 "this site has no pane with the id nowhere"),
                (["add-pane", "Corpus_Sites", "--place", "shrine", "--line", "Words."], 2, "needs --id (a talk action opens it) or --when"),
                (["add-pane", "Corpus_Sites", "--place", "shrine", "--id", "x"], 2, "at least one --line"),
                (["add-flag", "Corpus_Sites", "Bad Name"], 2, "A flag's name is 1 to 40"),
                (["add-foe", "Corpus_Sites", "--id", "g", "--name", "G", "--deck", str(self.work / "none.txt")], 2, "could not be read"),
                (["add-foe", "Corpus_Sites", "--id", "g", "--name", "G", "--deck", str(empty)], 2, "holds no cards"),
                (["add-foe", "Corpus_Sites", "--id", "g", "--name", "G", "--deck", str(deck)], 1, "Lightning Blot is not a card"),
                (["add-foe", "Corpus_Sites", "--id", "g", "--name", "G", "--deck", str(deck), "--face", "0"], 1, "0 is outside 1..200"),
                (["set-text", "Corpus_Sites", "Shrine Intro", "Words."], 2, "A text key is 1 to 64"),
                (["set-text", "Corpus_Sites", "shrine.intro", "  "], 2, "non-empty text"),
                (["set-text", "Corpus_Sites", "shrine.intro", "A {weird} word."], 1, "unknown placeholder {weird}"),
                (["set-info", "Corpus_Sites"], 2, "set-info needs something to set"),
                (["set-info", "Corpus_Sites", "--version", "one"], 1, "plugin.json"),
                (["remove-place", "Corpus_Sites", "--id", "shrine"], 2, "is the plugin's only place"),
                (["remove-place", "Corpus_Sites", "--id", "tower"], 2, "has no place tower"),
                (["add-action", str(FIXTURES / "good_minimal"), "--place", "p", "--id", "x"], 2, "is an island plugin")):
            with self.subTest(args=args[:1] + args[2:]):
                result = self.tool(*args, ok=False)
                self.assertEqual(result.returncode, code, result.stdout + result.stderr)
                self.assertIn(wanted, result.stdout + result.stderr)
                if code == 1:
                    self.assertIn("nothing was changed" if args[0] != "set-info" else "was not changed", result.stderr)
                self.assertEqual(self.snapshot(), before, "nothing was changed")

    def test_set_text_set_info_and_the_two_names(self):
        new = self.tool("set-text", "Corpus_Sites", "shrine.extra", "  A new line.  ")
        self.assertIn("Set the new text shrine.extra in Corpus_Sites; name it in a pane's lines or an action to show it.", new.stdout)
        changed = self.tool("set-text", "Corpus_Sites", "shrine.leave", "Walk on")
        self.assertIn("Changed the text shrine.leave in Corpus_Sites (it was: Leave).", changed.stdout)
        own = self.tool("set-text", "Corpus_Sites", "site.no_gold", "Not enough: {price} gold are asked, and you carry {gold}.")
        self.assertIn("It replaces the game's own sentence (\"You need {price} gold for this; you carry {gold}.\")", own.stdout)
        self.assertEqual(self.text()["shrine.extra"], "A new line.")
        poor = ap.walk_site(self.judged()["data"], "shrine", 0)["steps"][0]
        self.assertEqual(poor["buttons"][0]["why"], "Not enough: 20 gold are asked, and you carry 0.")
        self.assertEqual(poor["buttons"][1]["label"], "Walk on")
        info = self.tool("set-info", "Corpus_Sites", "--name", "Shrines", "--description", "A shrine by the road.",
                         "--license", "CC BY 4.0", "--author", "Ann", "--author", "Bo", "--version", "1.2.0",
                         "--note", "A study.")
        self.assertIn("Set name, description, license, version, learning_note, authors in Corpus_Sites's plugin.json.", info.stdout)
        manifest = json.loads((self.folder / "plugin.json").read_text(encoding="utf-8"))
        self.assertEqual((manifest["name"], manifest["description"], manifest["license"], manifest["authors"],
                          manifest["version"], manifest["learning_note"], manifest["api_version"], manifest["plugin_format"]),
                         ("Shrines", "A shrine by the road.", "CC BY 4.0", ["Ann", "Bo"], "1.2.0", "A study.", 2, 1))
        self.assertEqual(len(self.warnings()), 2, "the license and the description are written; the art and one unused text stay")
        counted = self.tool("add-counter", "Corpus_Sites", "coins")
        self.assertIn("Change it with --effect counter=coins+1, read it with --when counter=coins:3", counted.stdout)
        flagged = self.tool("add-flag", "Corpus_Sites", "wished")
        self.assertIn("Set it with --effect set_flag=wished", flagged.stdout)
        self.assertEqual((self.sites()["flags"], self.sites()["counters"]), (["wished"], ["coins"]))
        self.assertEqual(self.tool("add-flag", "Corpus_Sites", "wished", ok=False).returncode, 2)

    def test_remove_place_takes_its_words_pictures_and_what_only_it_used(self):
        before = self.snapshot()
        self.tool("add-place", "Corpus_Sites", "--id", "ring", "--name", "The Ring", "--recipe", "duelist")
        self.tool("add-place", "Corpus_Sites", "--id", "errand", "--name", "The Errand", "--recipe", "quest")
        self.tool("add-action", "Corpus_Sites", "--place", "shrine", "--id", "brag", "--when", "counter=ring_wins:1",
                  "--label", "Brag of your wins")
        gone = self.tool("remove-place", "Corpus_Sites", "--id", "errand")
        self.assertIn("Removed the place errand (The Errand) from Corpus_Sites: 15 texts (errand.*) and "
                      "art/corpus_sites_errand.png, art/corpus_sites_errand_map.png.", gone.stdout)
        self.assertIn("Removed with it, since nothing else used them: the task errand_errand, the flag errand_asked, "
                      "the flag errand_done.", gone.stdout)
        ring = self.tool("remove-place", "Corpus_Sites", "--id", "ring")
        self.assertIn("the foe ring_champ", ring.stdout)
        self.assertNotIn("ring_wins", ring.stdout, "the shrine still reads the counter")
        sites = self.sites()
        self.assertEqual((list(sites["sites"]), sites["flags"], sites["counters"], sites["foes"], sites["tasks"]),
                         (["shrine"], [], ["ring_wins"], {}, {}))
        self.assertFalse([key for key in self.text() if key.startswith(("ring.", "errand."))])
        self.assertEqual(sorted(files_of(self.folder)), sorted(before))
        self.judged()
        self.tool("add-place", "Corpus_Sites", "--id", "inn", "--name", "The Inn", "--recipe", "lore")
        self.tool("add-action", "Corpus_Sites", "--place", "shrine", "--id", "nod", "--when", "site_used=inn.ask",
                  "--label", "Nod")
        kept = self.snapshot()
        refused = self.tool("remove-place", "Corpus_Sites", "--id", "inn", ok=False)
        self.assertEqual(refused.returncode, 1)
        self.assertIn("site_used: no place inn in sites.json sites.", refused.stdout)
        self.assertEqual(self.snapshot(), kept, "another place still asks about it: nothing was changed")


class MinimumGame(Work):
    def test_a_plugin_raised_to_api_three_names_the_first_game_that_reads_it(self):
        manifest = self.folder / "plugin.json"
        raw = json.loads(manifest.read_text(encoding="utf-8"))
        raw["minimum_game_version"] = "0.70.4"
        manifest.write_text(json.dumps(raw, indent="\t"), encoding="utf-8")
        plain = self.tool("add-flag", "Corpus_Sites", "told")
        self.assertNotIn("minimum_game_version", plain.stdout)
        self.assertEqual(json.loads(manifest.read_text(encoding="utf-8"))["minimum_game_version"], "0.70.4")
        raised = self.tool("add-counter", "Corpus_Sites", "wins")
        self.assertIn("plugin.json: api_version is now 3", raised.stdout)
        self.assertIn("plugin.json: minimum_game_version is now %s, the first game that reads API 3." % ap.SITES_WORDS_GAME,
                      raised.stdout)
        now = json.loads(manifest.read_text(encoding="utf-8"))
        self.assertEqual((now["api_version"], now["minimum_game_version"]), (3, ap.SITES_WORDS_GAME))
        again = self.tool("add-counter", "Corpus_Sites", "more")
        self.assertNotIn("minimum_game_version", again.stdout)

    def test_a_later_minimum_stays_and_a_missing_one_is_written(self):
        manifest = self.folder / "plugin.json"
        raw = json.loads(manifest.read_text(encoding="utf-8"))
        raw.pop("minimum_game_version", None)
        manifest.write_text(json.dumps(raw, indent="\t"), encoding="utf-8")
        self.assertIn("minimum_game_version is now " + ap.SITES_WORDS_GAME, self.tool("add-counter", "Corpus_Sites", "wins").stdout)
        self.assertEqual(json.loads(manifest.read_text(encoding="utf-8"))["minimum_game_version"], ap.SITES_WORDS_GAME)
        self.assertGreaterEqual(ap.compare_versions(self.game.version, ap.SITES_WORDS_GAME), 0,
                                "this game reads API 3: its version is the first such, or later")
        self.assertEqual(ap.compare_versions("0.70.10", ap.SITES_WORDS_GAME), 1)


class ZipRefusals(Work):
    """The game's zip reader of 2026-11-22 (PluginPackage.zip_entries,
    entry_bytes, engine_agrees), mirrored: one list of files a zip, every
    entry's own header agreeing with it, every entry read to exactly its
    listed size. The cases are tests/unit/test_c1122_files.gd's, built
    here from bytes; the sentences are the game's (DriftTest holds them)."""

    def plain(self, method: int = 0) -> bytes:
        import io
        import zipfile
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w", compression=method) as archive:
            for rel in files_of(self.folder):
                info = zipfile.ZipInfo("Corpus_Sites/" + rel, (2026, 1, 1, 0, 0, 0))
                info.compress_type = method
                archive.writestr(info, (self.folder / rel).read_bytes())
        return buffer.getvalue()

    def judge_bytes(self, data: bytes) -> dict:
        path = self.work / "Hostile.zip"
        path.write_bytes(data)
        return ap.judge(str(path), self.game)

    @staticmethod
    def end_of(data: bytes) -> int:
        return data.rfind(b"PK\x05\x06")

    @staticmethod
    def with_comment(data: bytes, comment: bytes) -> bytes:
        import struct
        end = data.rfind(b"PK\x05\x06")
        return data[:end + 20] + struct.pack("<H", len(comment)) + comment

    def refused(self, data: bytes, reason: str, what: str) -> None:
        result = self.judge_bytes(data)
        self.assertFalse(result["valid"], what)
        self.assertEqual(result["problems"][0], reason, what)
        self.assertEqual(result["files"], {}, what + ": nothing of it is held")
        listed = run_tool("validate", str(self.work / "Hostile.zip"))
        self.assertEqual((listed.returncode, listed.stdout.splitlines()[0]), (1, reason), what)

    def test_whole_zips_read_as_ever_stored_deflated_and_with_a_plain_comment(self):
        for method in (0, 8):
            self.assertTrue(self.judge_bytes(self.plain(method))["valid"], method)
        self.assertTrue(self.judge_bytes(self.with_comment(self.plain(), b"made with care"))["valid"])
        exported, _, _ = ap.export_bytes(str(self.folder), self.game)
        self.assertTrue(self.judge_bytes(exported)["valid"])

    def test_a_second_end_record_bytes_after_the_zip_and_a_cut_mark(self):
        import struct
        plain = self.plain()
        fake = struct.pack("<IHHHHIIH", 0x06054B50, 0, 0, 1, 1, 46, 0, 0)
        self.refused(self.with_comment(plain, b"see: " + fake + b" :end"),
                     "Hostile.zip holds a second end record after its list of files; save it as a plain zip.",
                     "an end record in the comment")
        self.refused(plain + b"trailing garbage, not a zip's own",
                     "Hostile.zip is not a whole zip (its list of files is missing).", "bytes after the zip")
        self.refused(self.with_comment(plain, b"x" + fake[:4]),
                     "Hostile.zip holds a second end record after its list of files; save it as a plain zip.",
                     "an end mark as the comment's last bytes")
        # Two zips in one file: the last end mark's "list" is not a list of rows alone.
        both = self.judge_bytes(plain + self.plain(8))
        self.assertFalse(both["valid"])
        self.assertIn(both["problems"][0], ("Hostile.zip: a zip64 or damaged zip; save it as a plain zip.",
                                            "Hostile.zip is damaged (its list of files)."))

    def test_a_zip64_record_a_second_disk_and_a_list_longer_than_its_rows(self):
        import struct
        plain = self.plain()
        damaged = "Hostile.zip: a zip64 or damaged zip; save it as a plain zip."
        record = struct.pack("<I", 0x06064B50) + bytes(52)
        locator = struct.pack("<IIqI", 0x07064B50, 0, len(plain), 1)
        self.refused(self.with_comment(plain, record + locator), damaged, "a zip64 record and its locator")
        end = self.end_of(plain)
        for at, what in ((4, "this disk's number"), (6, "the list's disk")):
            self.refused(plain[:end + at] + struct.pack("<H", 1) + plain[end + at + 2:], damaged, what)
        count = struct.unpack_from("<H", plain, end + 10)[0]
        self.refused(plain[:end + 8] + struct.pack("<H", count - 1) + plain[end + 10:], damaged, "two counts that differ")
        fewer = plain[:end + 8] + struct.pack("<HH", count - 1, count - 1) + plain[end + 12:]
        self.refused(fewer, "Hostile.zip is damaged (its list of files).", "a list holding more bytes than its rows")
        # A row that names another disk is never read.
        offset = struct.unpack_from("<I", plain, end + 16)[0]
        result = self.judge_bytes(plain[:offset + 34] + struct.pack("<H", 1) + plain[offset + 36:])
        self.assertFalse(result["valid"])
        self.assertTrue(result["problems"][0].endswith(": could not be read whole."), result["problems"])

    def test_an_entry_whose_own_header_disagrees_with_the_list_is_never_read(self):
        import struct
        plain = self.plain()
        at = plain.index(b"Corpus_Sites/plugin.json") - 30
        self.assertEqual(plain[at:at + 4], b"PK\x03\x04")
        whole = "plugin.json: could not be read whole."
        for patch, what in ((plain[:at + 22] + struct.pack("<I", 40 * 1024 * 1024) + plain[at + 26:], "its size"),
                            (plain[:at + 18] + struct.pack("<I", 7) + plain[at + 22:], "its packed size"),
                            (plain[:at + 8] + struct.pack("<H", 8) + plain[at + 10:], "its method"),
                            (plain[:at + 14] + struct.pack("<I", 1) + plain[at + 18:], "its CRC-32"),
                            (plain[:at + 30] + b"Corpus_Sites/plugin.jsoX" + plain[at + 54:], "its name"),
                            (plain[:at + 26] + struct.pack("<H", 23) + plain[at + 28:], "its name's length"),
                            (plain[:at] + b"XX" + plain[at + 2:], "its mark")):
            result = self.judge_bytes(patch)
            self.assertFalse(result["valid"], what)
            self.assertIn(whole, result["problems"], what)
            self.assertNotIn("plugin.json", result["files"], what + ": the lying entry is not held")

    def test_an_entry_is_read_to_exactly_its_listed_size(self):
        import struct
        packed = self.plain(8)
        end = self.end_of(packed)
        offset = struct.unpack_from("<I", packed, end + 16)[0]
        row = packed.index(b"Corpus_Sites/text.json", offset) - 46
        local = packed.index(b"Corpus_Sites/text.json") - 30
        size = struct.unpack_from("<I", packed, row + 24)[0]
        for claimed, what in ((size - 1, "a size one short of what it unpacks to"), (size + 1, "a size one past it")):
            lying = packed[:local + 22] + struct.pack("<I", claimed) + packed[local + 26:row + 24] \
                + struct.pack("<I", claimed) + packed[row + 28:]
            result = self.judge_bytes(lying)
            self.assertFalse(result["valid"], what)
            self.assertIn("text.json: could not be read whole.", result["problems"], what)
        # A claim no deflate stream can honor is refused unread.
        source = self.work / "Whole.zip"
        source.write_bytes(packed)
        listed = ap.zip_entries(str(source))
        entry = next(e for e in listed["entries"] if e["name"] == "Corpus_Sites/text.json")
        with open(source, "rb") as handle:
            self.assertEqual(ap.entry_bytes(handle, listed, entry, entry["size"]), (self.folder / "text.json").read_bytes())
            self.assertIsNone(ap.entry_bytes(handle, listed, entry, entry["size"] - 1), "a cap below its size")
            self.assertIsNone(ap.entry_bytes(handle, listed, dict(entry, size=2 * 1024 * 1024, packed=20), 1 << 30))
            self.assertIsNone(ap.entry_bytes(handle, listed, dict(entry, crc=entry["crc"] ^ 1), entry["size"]))

    def test_the_rules_are_the_games(self):
        source = (ROOT / "game/adventure/plugins/plugin_package.gd").read_text(encoding="utf-8")
        for line in ("const MAX_RATIO := %d" % ap.MAX_RATIO, "const SIG_END64 := 0x06064b50", "const SIG_LOCATOR64 := 0x07064b50",
                     "holds a second end record after its list of files; save it as a plain zip.",
                     "or tail.decode_u16(end + 4) != 0 or tail.decode_u16(end + 6) != 0 or tail.decode_u16(end + 8) != count:",
                     "if at != directory.size():",
                     "if (method == 0 and packed != size) or (method == 8 and size > packed * MAX_RATIO + 64):",
                     "if value != int(pair[1]) and not (streamed and value == 0):",
                     "if not engine_agrees(path, listed[\"entries\"]):"):
            self.assertIn(line, source, "PluginPackage no longer says: " + line)


class Recipes(Work):
    def test_list_recipes_prints_one_line_each(self):
        listed = self.tool("add-place", "--list-recipes").stdout.splitlines()
        self.assertEqual([line.split()[0] for line in listed], list(ap.RECIPES))
        self.assertEqual(list(ap.RECIPES), ["lore", "gift", "healer", "toll", "gambler", "riddle", "collector", "duelist",
                                           "shop", "quest", "traveler", "teacher"])
        self.assertTrue(all(len(line) > 30 for line in listed))
        self.assertEqual(self.tool("add-place", "Corpus_Sites", "--id", "x", ok=False).returncode, 2)

    def test_every_recipe_writes_a_whole_place_that_validates_walks_and_exports(self):
        ## What a walk must have done by its end, and the hero it needs.
        proofs = {
            "lore": ([], lambda s, h: "p_lore.ask" in s["uses"] and s["flags"] == ["p_lore_told"]),
            "gift": ([], lambda s, h: s["food"] == 5 and s["amulets"] == {"white": 1} and s["uses"] == {"p_gift.gift": 1}),
            "healer": ([], lambda s, h: s["uses"]["p_healer.bless"] == 1 and s["gift"] == "5 more life" and s["food"] == 6),
            "toll": (["--color", "green", "--amulets", "red=1", "--day", "30"], lambda s, h: s["flags"] == ["p_toll_open"] and "p_toll.look" in s["uses"]),
            "gambler": (["--roll", "3"], lambda s, h: s["gold"] == 1000 - 250 + 750 and s["counters"] == {"p_gambler_plays": 5}),
            "riddle": ([], lambda s, h: s["flags"] == ["p_riddle_solved"] and s["gold"] == 1100 and s["counters"] == {"p_riddle_tries": 1}),
            "collector": (["--cards", "Llanowar Elves,Llanowar Elves,Llanowar Elves"], lambda s, h: s["gold"] == 1450 and s["counters"] == {"p_collector_trades": 3} and "cards" not in s),
            "duelist": (["--win"], lambda s, h: s["gold"] == 1000 + 3 * 50 and s["counters"] == {"p_duelist_wins": 3}),
            "shop": (["--cards", "Glasses of Urza"], lambda s, h: s["gold"] == 1000 - 300 - 200 + 60 and s["cards"][1:] == ["Jayemdae Tome", "Rod of Ruin"]),
            "quest": (["--cards", "Healing Salve"], lambda s, h: s["flags"] == ["p_quest_asked", "p_quest_done"] and s["gold"] == 1200),
            "traveler": ([], lambda s, h: s["gold"] == 800 and s["uses"] == {"p_traveler.ride": 2}),
            "teacher": (["--gold", "2000"], lambda s, h: s["magics"] == ["Dwarven Pick"] and s["life_bonus"] == 3 and s["gold"] == 2000 - 800 - 900),
        }
        for group in RECIPE_CASES.values():
            shutil.rmtree(self.folder)
            shutil.copytree(FIXTURES / "good_sites", self.folder)
            for recipe in group:
                with self.subTest(recipe=recipe):
                    key = "p_" + recipe
                    done = self.tool("add-place", "Corpus_Sites", "--id", key, "--name", "The " + recipe.title(), "--recipe", recipe)
                    self.assertIn("the recipe %s (%s)" % (recipe, ap.RECIPES[recipe][1]), done.stdout)
                    self.assertIn("walk Corpus_Sites --site " + key, done.stdout)
                    self.assertEqual(self.api(), 3)
                    look = ap.RECIPES[recipe][0]
                    self.assertEqual((self.folder / "art" / ("corpus_sites_%s_map.png" % key)).read_bytes(),
                                     ap._sprite(*ap.PLACE_LOOKS[look]), "the recipe's own stand-in look")
                    words = {k: v for k, v in self.text().items() if k.startswith(key + ".")}
                    self.assertGreaterEqual(len(words), 4)
                    self.assertFalse([v for v in words.values() if ap.STAND_IN_MARK in v], "readable sentences, not stand-ins")
                    options, proof = proofs[recipe]
                    walked = self.tool("walk", "Corpus_Sites", "--site", key, "--gold", "1000", "--json", *options)
                    report = json.loads(walked.stdout)
                    state = report["sites"][0]["steps"][-1]["state"]
                    self.assertTrue(proof(state, None), "%s: %s" % (recipe, state))
                    self.assertFalse([line for line in report["never_reached"][key] if "was ready, but" not in line],
                                     "with that hero nothing stands in the way of a pane or a button")
            said = [w for w in self.warnings() if "stand-in" not in w]
            self.assertEqual(said, [], "a recipe's place has nothing to warn of but its stand-in art and manifest")
            self.assertEqual(self.tool("export", "Corpus_Sites", "--out", "dist").returncode, 0)

    def test_the_card_the_color_and_the_look_of_a_recipe(self):
        self.tool("add-place", "Corpus_Sites", "--id", "camp", "--name", "The Camp", "--recipe", "collector",
                  "--card", "Ornithopter", "--look", "stone", "--where", "mainland,islands")
        self.tool("add-place", "Corpus_Sites", "--id", "gate", "--name", "The Gate", "--recipe", "toll", "--color", "blue")
        self.tool("add-place", "Corpus_Sites", "--id", "box", "--name", "The Box", "--recipe", "gift", "--card", "Sol Ring")
        sites = self.sites()["sites"]
        self.assertEqual(ap._site_actions(sites["camp"])["trade"]["needs"], [{"card": "Ornithopter"}])
        self.assertEqual(sites["camp"]["where"], ["mainland", "islands"])
        self.assertIn({"hero_color": "blue"}, ap._site_actions(sites["gate"])["kin"]["when"])
        self.assertEqual(ap._site_actions(sites["box"])["gift"]["effects"], [{"give_card": "Sol Ring"}])
        self.assertEqual((self.folder / "art/corpus_sites_camp.png").read_bytes(), ap._site_picture(*ap.PLACE_LOOKS["stone"]))
        bad = self.tool("add-place", "Corpus_Sites", "--id", "c2", "--name", "C", "--recipe", "collector", "--card",
                        "Ornithoptre", ok=False)
        self.assertEqual(bad.returncode, 1)
        self.assertIn("the nearest card names to Ornithoptre: Ornithopter", bad.stderr)
        self.assertNotIn("c2", self.sites()["sites"])


class Walks(Work):
    def test_press_plays_the_buttons_named_and_says_what_is_not_there(self):
        result = self.tool("walk", "Corpus_Sites", "--press", "bless,bless,nothing", ok=False)
        self.assertEqual(result.returncode, 2)
        self.assertIn("--press nothing: the place shrine has no such button (its buttons: leave, bless; and leave, clear).", result.stderr)
        run = json.loads(self.tool("walk", "Corpus_Sites", "--site", "shrine", "--land", "mainland", "--press",
                                   "bless,bless,clear,bless,bless", "--gold", "70", "--json").stdout)["sites"]
        self.assertEqual(len(run), 1, "--land walks one land")
        steps = run[0]["steps"]
        self.assertEqual([s["kind"] for s in steps], ["pane", "press", "pane", "press", "pane", "note", "pane", "press",
                                                     "pane", "press", "pane"])
        self.assertEqual(steps[5]["text"], "clear: no dungeon is open.")
        self.assertEqual(steps[7]["refused"], "You need 80 gold for this; you carry 10.")
        self.assertEqual(steps[9]["refused"], steps[7]["refused"])
        gone = ap.walk_site(self.judged()["data"], "shrine", 500, "mainland", press=["bless", "bless", "bless", "bless"])
        self.assertIn("bless: this pane shows no such button (its buttons: leave).", gone["steps"][-2]["text"])
        self.assertEqual(steps[-1]["state"]["gold"], 10)
        text = self.tool("walk", "Corpus_Sites", "--site", "shrine", "--press", "bless", "--gold", "5").stdout
        self.assertIn('Press "Leave 20 gold in the bowl (3 left)": refused, nothing paid', text)
        self.assertNotIn("Never reached", text, "a walk that is told what to press lists nothing")
        self.assertEqual(self.tool("add-place", "Corpus_Sites", "--id", "b", "--name", "B", "--service", "none").returncode, 0)
        self.assertIn("name the place with --site", self.tool("walk", "Corpus_Sites", "--press", "leave", ok=False).stderr)

    def test_the_heros_options_are_checked_and_reach_every_condition(self):
        for args, wanted in ((["--flag", "nope"], "sites.json flags has no nope"),
                             (["--counter", "wins=1"], "sites.json counters has no wins"),
                             (["--counter", "wins"], "--counter takes name=number"),
                             (["--amulets", "pink=1"], "with a color of black, blue, green, red, white"),
                             (["--color", "pink"], "--color takes one of"),
                             (["--win", "--lose"], "a duel ends one way"),
                             (["--land", "island", "--both"], "name one"),
                             (["--gold", "-1"], "--gold must be 0 or more")):
            refused = self.tool("walk", "Corpus_Sites", *args, ok=False)
            self.assertEqual(refused.returncode, 2, args)
            self.assertIn(wanted, refused.stderr)
        case = next(c for c in corpus()["cases"] if c["name"] == "good_sites_api3_every_word")
        path = build_case(case, self.work, "Every")
        data = ap.judge(str(path), self.game)["data"]
        hero = ap.walk_hero(data, 500, {"food": 9, "flags": [], "counters": {"wins": 3}, "cards": ["Lightning Bolt", "Lightning Bolt", "Gray Ogre"],
                                        "amulets": {"red": 2, "blue": 1}, "color": "red", "magics": ["Dwarven Pick"], "day": 5,
                                        "wizards": 1, "difficulty": 1, "plugins": ["old_hut"], "linked": True})
        self.assertEqual(hero.pane_of("den"), data["sites"]["sites"]["den"]["panes"][0], "three wins, and a red hero")
        hero.counters["wins"] = 0
        hero.uses["shrine.bless"] = 1
        pane = hero.describe("den")
        self.assertEqual(pane["lines"], ["A low den under a hill.", "Day 5: the den is quiet.", "You carry 9 food and 3 amulets.",
                                         "You carry 500 gold."], "one_of by the den's uses (0) and by day (5); every condition of the line holds")
        self.assertEqual([(b["id"], b["ready"]) for b in pane["buttons"]],
                         [("ask", True), ("bribe", True), ("gamble", True), ("fight", True), ("buy", True), ("sell", True), ("ride", False),
                          ("leave", True)], "the ride would link a town that is linked already")
        self.assertEqual(pane["buttons"][2]["label"], "Throw the bones (10 gold, 2 left; Lightning Bolt)")
        self.assertEqual(pane["buttons"][3]["label"], "Fight The Den Keeper (12 life) for 25 gold")
        hero.roll_choice = 2
        done = hero.press("den", "gamble")
        self.assertEqual(done["taken"], ["Lightning Bolt", "2 any amulets", "1 food"])
        self.assertEqual((hero.amulets["red"], hero.amulets["blue"], hero.food, hero.cards.count("Lightning Bolt")), (2, 0, 8, 1),
                         "any amulets from the color the hero has most of, one at a time; then one red given")
        self.assertEqual((done["given"], done["gift"], done["revealed"]), (["Llanowar Elves"], "5 more life", ["3 tiles around the place"]))
        self.assertEqual(done["rolls"][0]["weights"], [3, 1, 1])
        self.assertEqual(done["rolls"][0]["expected_gold"], 12.0)
        self.assertEqual(done["lines"], ["It is said.", "You lose, after 1 tries."], "the action's lines, then the outcome's")
        hero.cards.remove("Lightning Bolt")
        again = hero.press("den", "gamble")
        self.assertEqual(again["refused"], "You need Lightning Bolt for this; you hold none.")
        hero.cards.append("Lightning Bolt")
        self.assertEqual(hero.press("den", "gamble")["refused"], "You need 2 amulets for this; you carry 2."
                         if hero.amulet_count() < 2 else "A gift for your next duel already waits; fight that duel first.")
        hero.amulets["black"] = 2
        self.assertEqual(hero.press("den", "gamble")["refused"], "A gift for your next duel already waits; fight that duel first.")
        hero.duel_outcome = "lose"
        lost = hero.press("den", "fight")
        self.assertEqual((lost["duel"], lost["lines"], hero.used("den", "fight"), hero.gift), ("lost", ["You lose, after 0 tries."], 0, ""))
        hero.duel_outcome = "win"
        won = hero.press("den", "fight")
        self.assertEqual((won["duel"], hero.used("den", "fight"), hero.counter("wins")), ("won", 1, 1))
        self.assertEqual(hero.press("den", "bribe")["to"], "back_room")
        self.assertEqual(hero.describe("den", "back_room")["title"], "The back room")
        self.assertEqual(hero.describe("den", "nowhere")["pane"], 1, "a pane that is not there: the place's own")

    def test_a_roll_is_shown_whole_with_its_weights_and_its_average(self):
        self.tool("add-place", "Corpus_Sites", "--id", "den", "--name", "The Den", "--recipe", "gambler")
        text = self.tool("walk", "Corpus_Sites", "--site", "den").stdout
        for line in ("     a roll of 3 outcomes; this walk takes outcome 1 (--roll N chooses); on average 50 gold",
                     "       > outcome 1: 3 in 6, 0 gold: Low numbers. He sweeps your gold away with a shrug.",
                     "         outcome 2: 2 in 6, 75 gold: A fair throw! He counts out 75 gold.",
                     "         outcome 3: 1 in 6, 150 gold: Three sixes! He pays out 150 gold and looks at the dice twice.",
                     "  End: 99750 gold; uses den.bet 5; flags none; dungeons none; counters den_plays 5."):
            self.assertIn(line, text)
        third = self.tool("walk", "Corpus_Sites", "--site", "den", "--roll", "3", "--gold", "100").stdout
        self.assertIn("       > outcome 3: 1 in 6, 150 gold", third)
        self.assertIn("  End: 600 gold;", third)
        self.assertEqual(self.tool("walk", "Corpus_Sites", "--site", "den").stdout, text, "the same walk every time")

    def test_never_reached_names_what_stood_in_the_way_and_how_to_get_there(self):
        self.tool("add-place", "Corpus_Sites", "--id", "camp", "--name", "The Camp", "--recipe", "collector")
        self.tool("add-place", "Corpus_Sites", "--id", "gate", "--name", "The Gate", "--recipe", "toll")
        result = self.tool("walk", "Corpus_Sites")
        tail = result.stdout[result.stdout.index("Never reached in this walk"):]
        self.assertIn('  camp: pane 0 was never shown: its when is [{"used_up": "trade"}]', tail)
        self.assertIn('  camp: the button trade was never shown: its when is [{"has_card": {"card": "Llanowar Elves", "min": 1}}] '
                      '(try --cards "Llanowar Elves")', tail)
        self.assertIn("(try --amulets white=1)", tail)
        self.assertIn("(try --color green)", tail)
        self.assertNotIn("shrine", tail)
        self.assertEqual(result.returncode, 0, "a walk that misses something is still a walk")
        report = json.loads(self.tool("walk", "Corpus_Sites", "--json").stdout)
        self.assertEqual(report["never_reached"]["shrine"], [])
        self.assertEqual(len(report["never_reached"]["camp"]), 2)
        whole = self.tool("walk", "Corpus_Sites", "--site", "camp", "--cards", "Llanowar Elves, Llanowar Elves, Llanowar Elves")
        self.assertIn("Every pane was shown and every button pressed.", whole.stdout)
        self.assertIn("     taken: Llanowar Elves", whole.stdout)


class InfoAndCompat(Work):
    def test_info_lists_counters_foes_tasks_and_the_words_of_api_three(self):
        plain = self.tool("info", "Corpus_Sites").stdout
        self.assertIn("words of API 3:       none (a game that reads API 2 plays it)", plain)
        self.assertIn("warnings:             3 (validate lists them)", plain)
        self.tool("add-place", "Corpus_Sites", "--id", "ring", "--name", "The Ring", "--recipe", "duelist")
        self.tool("add-place", "Corpus_Sites", "--id", "errand", "--name", "The Errand", "--recipe", "quest")
        text = self.tool("info", "Corpus_Sites").stdout
        for line in ("  foe ring_champ:       The Champion, 20 life, a deck of 40 cards",
                     "  task errand_errand:   at place:errand", "  counters:             ring_wins"):
            self.assertIn(line, text)
        facts = json.loads(self.tool("info", "Corpus_Sites", "--json").stdout)["content"]
        self.assertEqual(facts["counters"], ["ring_wins"])
        self.assertEqual(facts["api_3_words"][:3], ["counters", "foes", "tasks"])
        for word in ("duel", "foe", "win", "lose", "talk", "to", "id", "needs", "has_card", "counter"):
            self.assertIn(word, facts["api_3_words"])

    def compat(self, edit) -> tuple:
        old = self.work / "old" / "Corpus_Sites"
        shutil.copytree(self.folder, old)
        edit()
        result = self.tool("compat", str(old), "Corpus_Sites", ok=False)
        shutil.rmtree(old.parent)
        return result.returncode, result.stdout

    def test_compat_knows_counters_stock_and_a_dungeon_bought_on_both_lands(self):
        self.tool("add-place", "Corpus_Sites", "--id", "ring", "--name", "The Ring", "--recipe", "duelist")
        self.tool("add-action", "Corpus_Sites", "--place", "shrine", "--id", "buy", "--do", "buy", "--cards", "Swamp=5", "--stock", "3")
        self.tool("add-action", "Corpus_Sites", "--place", "shrine", "--id", "tell", "--prices", "100", "--label", "Ask")
        self.tool("add-dungeon", "Corpus_Sites", "--id", "pit", "--name", "The Pit", "--cards", "Swamp")

        def rename_counter():
            for name in ("sites.json", "text.json"):
                path = self.folder / name
                path.write_text(path.read_text(encoding="utf-8").replace("ring_wins", "ring_won"), encoding="utf-8")

        code, said = self.compat(rename_counter)
        self.assertEqual(code, 1)
        self.assertIn("sites.json counters: ring_wins was renamed or removed: saves keep what it counted under the old name", said)

        def less_stock_and_a_dungeon():
            sites = self.sites()
            for pane in sites["sites"]["shrine"]["panes"]:
                for action in pane["actions"]:
                    if action["id"] == "buy":
                        action["stock"] = 1
                    if action["id"] == "tell":
                        action["effects"] = [{"spawn_dungeon": "pit"}]
            (self.folder / "sites.json").write_text(json.dumps(sites), encoding="utf-8")

        code, said = self.compat(less_stock_and_a_dungeon)
        self.assertEqual(code, 0, said)
        self.assertIn("note: sites.json sites.shrine: the action buy's stock is now 1", said)
        self.assertIn("note: sites.json sites.shrine: the action tell now raises a dungeon for a price at a place on the "
                      "mainland and on islands: from now on its uses are counted on each land by itself", said)


class CheatSheet(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.game = ap.find_game()
        cls.schema = cls.game.schema()
        cls.page = (PLUGINS / "GUIDE" / "cheatsheet.html").read_text(encoding="utf-8")
        cls.rows = ap.cheat_rows(cls.game)

    def test_the_page_is_what_guide_writes_now(self):
        result = run_tool("guide", "--check")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("cheatsheet.html is up to date.", result.stdout)
        self.assertIn("reference.html is up to date.", result.stdout)
        work = Path(tempfile.mkdtemp(prefix="plugin-c1122-"))
        try:
            self.assertEqual(run_tool("guide", "--out", str(work)).returncode, 0)
            self.assertEqual(sorted(p.name for p in work.iterdir()), ["cheatsheet.html", "reference.html"])
            (work / "cheatsheet.html").write_text("old", encoding="utf-8")
            stale = run_tool("guide", "--out", str(work), "--check")
            self.assertEqual(stale.returncode, 1)
            self.assertIn("cheatsheet.html is not what guide writes from the schema now", stale.stdout)
        finally:
            shutil.rmtree(work, ignore_errors=True)

    def test_every_word_of_the_schema_has_its_row_in_the_schemas_order(self):
        types = self.schema["types"]
        self.assertEqual([row[0] for row in self.rows["conditions"]], list(types["sites_condition"]["options"]))
        self.assertEqual([row[0] for row in self.rows["effects"]], list(types["sites_effect"]["options"]))
        self.assertEqual([row[0] for row in self.rows["actions"]], types["sites_action"]["fields"]["do"]["values"])
        self.assertEqual([row[0] for row in self.rows["needs"]], list(types["sites_need"]["options"]))
        self.assertEqual([row[0] for row in self.rows["fields"]],
                         list(types["sites_file"]["fields"]) + list(types["sites_pane"]["fields"]) + list(types["sites_action"]["fields"]))
        shown = [row[0] for row in self.rows["placeholders"]]
        # {town} and {title} are an island's words that two kinds of a place's action fill too.
        self.assertEqual(shown, [name for name in self.schema["placeholders"]
                                 if name not in ap.ISLAND_PLACEHOLDERS or name in ("town", "title")])
        for group in ("conditions", "effects", "actions", "needs"):
            for row in self.rows[group]:
                self.assertIn("<code>%s</code>" % row[0], self.page, row[0])
                self.assertIn(html.escape(json.dumps(row[1], ensure_ascii=False)), self.page, row[0])
        for name in shown:
            self.assertIn("<code>{%s}</code>" % name, self.page)
        for recipe, (_, line) in ap.RECIPES.items():
            self.assertIn("<code>%s</code></td><td class=\"doc\" data-label=\"What it makes\">%s" % (recipe, html.escape(line)), self.page)
        # Every word has an example of its own, none made up from its shape.
        self.assertEqual(sorted(ap.CHEAT_WHEN), sorted(types["sites_condition"]["options"]))
        self.assertEqual(sorted(list(ap.CHEAT_EFFECT) + ["roll"]), sorted(types["sites_effect"]["options"]))
        self.assertEqual(sorted(ap.CHEAT_DO), sorted(types["sites_action"]["fields"]["do"]["values"]))
        self.assertEqual(sorted(ap.CHEAT_NEED), sorted(types["sites_need"]["options"]))
        v3 = self.schema["v3_words"]
        for row in self.rows["conditions"]:
            self.assertEqual(row[4] == "3", row[0] in v3["condition"], row[0])
        self.assertEqual(self.page.count('<span class="api">API 3</span>'),
                         1 + len(v3["condition"]) + len(v3["effect"]) + len(v3["do"]) + len(self.rows["needs"]) + 1
                         + len(v3["file"]) + len(v3["pane"]) + len(v3["action"]))

    def test_every_example_is_one_the_game_takes(self):
        """Each row's JSON is checked against the schema's own shape for it,
        and all of them together make a plugin the tool finds valid."""
        reader = ap.Content(self.game)
        types = self.schema["types"]
        for group, spec in (("conditions", "sites_condition"), ("effects", "sites_effect"), ("needs", "sites_need"),
                            ("actions", "sites_action")):
            for row in self.rows[group]:
                problems: list = []
                reader.check(row[1], {"kind": "ref", "type": spec}, row[0], problems, reader._refs(), {})
                self.assertEqual(problems, [], row[0])
        for name, value, _, _, _ in self.rows["lines"]:
            problems = []
            reader.check(value, {"kind": "ref", "type": "sites_line"}, name, problems, reader._refs(), {})
            self.assertEqual(problems, [], name)
        self.assertEqual(ap.example_of(self.schema, types["sites_condition"]["options"]["used"]), {"action": "name"})
        self.assertEqual(ap.example_of(self.schema, types["sites_effect"]["options"]["gold"]), 1)

    def test_every_command_line_of_the_page_runs_in_its_order(self):
        work = Path(tempfile.mkdtemp(prefix="plugin-c1122-"))
        try:
            (work / "deck.txt").write_text("12 Mountain\n4 Lightning Bolt\n", encoding="utf-8")
            (work / "answers.txt").write_text("The Mill\nlore\n", encoding="utf-8")
            import shlex
            named = set()
            for name, line in ap.COMMAND_EXAMPLES:
                with self.subTest(line=line):
                    self.assertIn(html.escape("python3 tools/adventure_plugin.py " + line), self.page)
                    args = shlex.split(line)
                    self.assertEqual(args[0], name)
                    named.add(name)
                    result = run_tool(*args, cwd=work)
                    self.assertEqual(result.returncode, 0, line + "\n" + result.stdout + result.stderr)
            self.assertEqual(named, {"new", "add-place", "add-pane", "add-action", "add-flag", "add-counter", "add-foe",
                                     "add-dungeon", "set-text", "set-info", "remove-place", "walk", "art", "validate",
                                     "info", "export", "compat", "guide", "wizard", "preview"})
            helped = run_tool("--help").stdout
            for name in named:
                self.assertIn(name, helped)
                self.assertEqual(run_tool(name, "--help").returncode, 0, name)
            judged = ap.judge(str(work / "My_Places"), self.game)
            self.assertTrue(judged["valid"], judged["problems"])
            self.assertEqual(sorted(judged["data"]["sites"]["sites"]), ["den", "mill", "ring", "well"])
        finally:
            shutil.rmtree(work, ignore_errors=True)


class GuidePage(unittest.TestCase):
    """sites.html's own claims about API 3 (tools/test_adventure_guide.py
    holds the page to the schema and to the two plugins of API 2)."""

    @classmethod
    def setUpClass(cls):
        cls.page = (PLUGINS / "GUIDE" / "sites.html").read_text(encoding="utf-8")

    def test_every_snippet_of_a_study_plugin_is_the_real_file(self):
        found = re.findall(r'<pre class="code" data-study="(\w+)" data-study-file="([\w.]+)" data-study-pointer="([^"]*)">'
                           r'<code>(.*?)</code></pre>', self.page, re.S)
        self.assertGreaterEqual(len(found), 5)
        self.assertEqual({folder for folder, _, _, _ in found}, set(STUDIES))
        for folder, name, pointer, body in found:
            with self.subTest(plugin=folder, pointer=pointer):
                value = json.loads((PLUGINS / folder / name).read_text(encoding="utf-8"))
                for part in [x for x in pointer.split("/") if x]:
                    value = value[int(part)] if isinstance(value, list) else value[part]
                self.assertEqual(json.loads(html.unescape(body)), value)

    def test_the_page_names_every_word_recipe_and_command(self):
        schema = ap.find_game().schema()
        for group in ("condition", "effect", "do", "file", "action", "line", "pane"):
            for word in schema["v3_words"][group]:
                self.assertIn("<code>%s</code>" % word, self.page, word)
        for need in schema["types"]["sites_need"]["options"]:
            self.assertIn("<code>%s</code>" % need, self.page)
        for recipe, (_, line) in ap.RECIPES.items():
            self.assertIn("<tr><td><code>%s</code></td><td class=\"wrap\">%s</td>" % (recipe, html.escape(line, quote=False)), self.page)
        for look in ap.PLACE_LOOKS:
            self.assertIn("<code>%s</code>" % look, self.page)
        plain = html.unescape(re.sub(r"<[^>]+>", "", self.page))
        for command in ("add-place", "add-action", "add-pane", "add-counter", "set-text", "set-info", "add-dungeon", "walk"):
            self.assertIn("python3 tools/adventure_plugin.py " + command, plain)
        for option in ("--recipe", "--list-recipes", "--free", "--press", "--both", "--win", "--lose", "--roll", "--flag",
                       "--counter", "--cards", "--food", "--land", "--effect", "--needs", "--when", "--outcome", "--pane"):
            self.assertIn(option, plain, option)
            self.assertIn('"%s"' % option, (TOOLS / "adventure_plugin.py").read_text(encoding="utf-8"), option)
        source = (ROOT / "game/adventure/plugins/plugin_schema.gd").read_text(encoding="utf-8")
        sentence = ('is a word of plugin API 3, and plugin.json declares api_version %d. Set \\"api_version\\": 3 there '
                    "(the plugin then needs a game that reads API 3).")
        self.assertIn(sentence, source)
        self.assertIn(sentence.replace("%d", "2").replace('\\"', '"'), plain)

    def test_the_tool_lines_of_the_page_run(self):
        import shlex
        work = Path(tempfile.mkdtemp(prefix="plugin-c1122-"))
        try:
            tools = self.page[self.page.index('<h2 id="tools">'):]
            lines = [html.unescape(re.sub(r"<[^>]+>", "", line)) for line in
                     re.findall(r'<span class="prompt">\$ </span>(python3 tools/adventure_plugin\.py (?:new|add-|set-).*?)</code>', tools)]
            self.assertGreaterEqual(len(lines), 9)
            for line in lines:
                with self.subTest(line=line):
                    result = run_tool(*shlex.split(line)[2:], cwd=work)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue(ap.judge(str(work / "my_places"), ap.find_game())["valid"])
        finally:
            shutil.rmtree(work, ignore_errors=True)


class StudyPlugins(unittest.TestCase):
    """The four study plugins: made with the tool's commands, which their
    READMEs keep as the recipe."""

    @classmethod
    def setUpClass(cls):
        cls.game = ap.find_game()

    def test_each_is_a_whole_places_plugin_of_api_three(self):
        for folder, ident in STUDIES.items():
            with self.subTest(plugin=folder):
                result = ap.judge(str(PLUGINS / folder), self.game)
                self.assertTrue(result["valid"], result["problems"])
                manifest = result["manifest"]
                self.assertEqual((manifest["id"], manifest["kind"], manifest["api_version"], manifest["version"]),
                                 (ident, "sites", 3, "1.0.0"))
                self.assertIn("Original fiction, not official Magic canon.", manifest["learning_note"])
                self.assertEqual(packs := ap.packs_of(manifest), [], packs)
                self.assertEqual(len(result["data"]["sites"]["sites"]), 1)
                for rel in ("README.txt", "LICENSE.txt"):
                    self.assertIn(rel, result["files"])
                self.assertEqual(manifest["minimum_game_version"], ap.SITES_WORDS_GAME, "the first game that reads API 3")
                # Its two pictures are its own (they may be repainted at any
                # size the game takes): art reads them and never refuses.
                art = ap.art_report(result)
                self.assertEqual(len(art), 1)
                self.assertAlmostEqual(art[0]["picture"]["aspect"], ap.PANE_WIDTH / ap.PANE_HEIGHT, places=1)
                self.assertEqual(run_tool("art", str(PLUGINS / folder)).returncode, 0)

    def test_each_readmes_commands_make_the_plugin_again(self):
        import shlex
        for folder in STUDIES:
            with self.subTest(plugin=folder):
                work = Path(tempfile.mkdtemp(prefix="plugin-c1122-"))
                try:
                    readme = (PLUGINS / folder / "README.txt").read_text(encoding="utf-8")
                    block = readme[readme.index("HOW IT WAS MADE"):readme.index("Then, to see it played")]
                    commands = [line.strip() for line in block.splitlines() if line.startswith("    python3 tools/adventure_plugin.py ")]
                    self.assertGreaterEqual(len(commands), 10)
                    used = set()
                    for rel in files_of(PLUGINS / folder):
                        if rel.endswith("_deck.txt"):
                            (work / folder).mkdir(exist_ok=True)
                    for line in commands:
                        args = shlex.split(line)[2:]
                        used.add(args[0])
                        if args[0] != "new":
                            # The deck lists add-foe reads lie in the plugin's folder.
                            for rel in files_of(PLUGINS / folder):
                                if rel.endswith("_deck.txt") and not (work / folder / rel).exists():
                                    shutil.copy(PLUGINS / folder / rel, work / folder / rel)
                        elif (work / folder).exists():
                            (work / folder).rmdir()
                        result = run_tool(*args, cwd=work)
                        self.assertEqual(result.returncode, 0, line + "\n" + result.stdout + result.stderr)
                    self.assertLessEqual({"new", "add-place", "remove-place", "set-text", "add-action", "set-info"}, used)
                    for rel in ("plugin.json", "sites.json", "text.json"):
                        made = json.loads((work / folder / rel).read_text(encoding="utf-8"))
                        shipped = json.loads((PLUGINS / folder / rel).read_text(encoding="utf-8"))
                        if rel == "plugin.json":
                            # new names the game it is run in; a later game names a later version.
                            self.assertGreaterEqual(ap.compare_versions(made.pop("minimum_game_version"),
                                                                        shipped.pop("minimum_game_version")), 0)
                        self.assertEqual(made, shipped, rel)
                finally:
                    shutil.rmtree(work, ignore_errors=True)

    def test_each_walks_to_its_end_and_exports(self):
        ## The hero each needs to reach everything, and what the walk ends with.
        walks = {"Gamblers_Den": (["--roll", "3", "--gold", "1000"],
                                  "End: 1700 gold; uses den.bet 5, den.high 2; flags none; dungeons none; counters den_plays 5; amulets red 2."),
                 "Riddle_Stone": (["--site", "stone", "--press", "answer_a,leave,answer_c,leave,listen,leave,answer_b", "--gold", "0"],
                                  "End: 100 gold; uses stone.answer_a 1, stone.answer_c 1, stone.answer_b 1; flags stone_solved; dungeons none; counters stone_tries 2."),
                 "Wandering_Collector": (["--cards", "Ornithopter,Ornithopter,Ornithopter", "--gold", "0"],
                                         "End: 450 gold; uses wagon.trade 3, wagon.gift 1; flags none; dungeons none; counters wagon_trades 3; food 4; amulets blue 1."),
                 "Duelists_Ring": (["--win", "--gold", "200"],
                                   "End: 600 gold; uses ring.duel 3, ring.master 1; flags none; dungeons none; counters ring_wins 4.")}
        work = Path(tempfile.mkdtemp(prefix="plugin-c1122-"))
        try:
            for folder, (options, end) in walks.items():
                with self.subTest(plugin=folder):
                    walked = run_tool("walk", str(PLUGINS / folder), *options)
                    self.assertEqual(walked.returncode, 0, walked.stderr)
                    self.assertIn("  " + end, walked.stdout)
                    if "--press" not in options:
                        left = walked.stdout.split("Never reached in this walk")[1:] if "Never reached" in walked.stdout else []
                        self.assertFalse([line for part in left for line in part.splitlines()[1:] if "was ready" not in line],
                                         walked.stdout[-600:])
                    exported = run_tool("export", str(PLUGINS / folder), "--out", str(work))
                    self.assertEqual(exported.returncode, 0, exported.stdout + exported.stderr)
                    self.assertTrue(ap.judge(str(work / (folder + ".zip")), self.game)["valid"])
        finally:
            shutil.rmtree(work, ignore_errors=True)

    def test_the_den_rolls_the_stone_talks_the_collector_needs_the_ring_duels(self):
        data = {folder: ap.judge(str(PLUGINS / folder), self.game)["data"]["sites"] for folder in STUDIES}
        den = ap._site_actions(data["Gamblers_Den"]["sites"]["den"])
        self.assertEqual([o["weight"] for o in den["bet"]["effects"][1]["roll"]["outcomes"]], [3, 2, 1])
        self.assertLessEqual(ap.SiteWalk.gold_of(den["high"]["effects"]), 200, "the house wins at the high table too")
        stone = data["Riddle_Stone"]["sites"]["stone"]
        self.assertEqual([p.get("id") for p in stone["panes"]], [None, None, "wrong", "right", "hint"])
        self.assertEqual(data["Riddle_Stone"]["counters"], ["stone_tries"])
        trade = ap._site_actions(data["Wandering_Collector"]["sites"]["wagon"])["trade"]
        self.assertEqual((trade["needs"], trade["when"], trade["effects"][0]),
                         ([{"card": "Ornithopter"}], [{"has_card": {"card": "Ornithopter", "min": 1}}], {"gold": 150}))
        ring = ap._site_actions(data["Duelists_Ring"]["sites"]["ring"])
        self.assertEqual((ring["duel"]["do"], ring["duel"]["foe"], ring["duel"]["prices"], ring["master"]["foe"]),
                         ("duel", "ring_champ", [50, 50, 50], "ringmaster"))
        self.assertIn({"counter": {"name": "ring_wins", "add": 1}}, ring["duel"]["win"]["effects"])
        self.assertEqual(sorted(data["Duelists_Ring"]["foes"]), ["ring_champ", "ringmaster"])


if __name__ == "__main__":
    unittest.main()
