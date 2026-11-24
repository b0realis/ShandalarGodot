#!/usr/bin/env python3
"""tools/adventure_plugin.py — the places campaign of 2026-11-22, its third
round: `preview` (one HTML page that shows every pane of a sites plugin's
places), `wizard` (a place made by answering questions), the recipes' own
numbers and names (`add-place --set`), two more recipes (traveler, teacher)
and the words they are made of — the effects teleport, world_magic,
mana_link and life_bonus, the conditions life_bonus_below and town_linked —
in validate (the corpus's sites_api3_ cases, judged by the game too), walk,
the warnings and the cheat sheet.

No Godot, no network. Run from the repo root:
    python3 tools/test_c1122_places_tool_r3.py
"""
from __future__ import annotations

import html
import json
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))
import adventure_plugin as ap  # noqa: E402
from test_adventure_plugin import FIXTURES, SCRIPT, build_case, corpus, files_of, run_tool  # noqa: E402
from test_c1122_places_tool import PLUGINS, STUDIES, Work  # noqa: E402

PREVIEW = FIXTURES / "preview" / "corpus_sites.html"


def words_of(page: str) -> str:
    """A page's words, its markup and style taken out."""
    body = page[page.index("<main>"):]
    return html.unescape(re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", body)))


class Preview(Work):
    def page(self, *args) -> str:
        out = self.work / "out"
        shutil.rmtree(out, ignore_errors=True)
        self.tool("preview", *args, "--out", str(out))
        return next(out.glob("*.html")).read_text(encoding="utf-8")

    def test_the_page_of_the_corpus_plugin_is_the_fixture_byte_for_byte(self):
        result = self.tool("preview", str(FIXTURES / "good_sites"), "--out", "out")
        self.assertIn("corpus_sites.html (", result.stdout)
        self.assertIn("1 place, 2 panes", result.stdout)
        made = (self.work / "out" / "corpus_sites.html").read_bytes()
        self.assertEqual(made, PREVIEW.read_bytes(), "the preview of tools/plugin_fixtures/good_sites changed: look at it, "
                         "then write it again with preview tools/plugin_fixtures/good_sites --out tools/plugin_fixtures/preview")
        self.tool("preview", "Corpus_Sites", "--out", "again")
        self.assertEqual((self.work / "again" / "corpus_sites.html").read_bytes(), made, "the same bytes for the same plugin")
        self.assertEqual(self.tool("validate", "Corpus_Sites").returncode, 0, "the page is written beside the plugin, not into it")

    def test_the_page_stands_alone_and_runs_nothing(self):
        for source in [str(FIXTURES / "good_sites")] + [str(PLUGINS / folder) for folder in STUDIES]:
            with self.subTest(plugin=source):
                page = self.page(source)
                self.assertTrue(page.startswith("<!DOCTYPE html>\n<html lang=\"en\">"))
                self.assertNotRegex(page, r"(?i)<script|<link|<iframe|<object|<embed|@import|javascript:|\son[a-z]+\s*=")
                self.assertNotRegex(page, r"(?i)https?:|//[a-z]")
                self.assertNotIn("text-shadow", page)
                self.assertIn("<style>", page)
                for source_of in re.findall(r'src="([^"]*)"', page):
                    self.assertTrue(source_of.startswith("data:image/") or not re.match(r"^[a-z]+:", source_of), source_of[:60])

    def test_a_plugins_words_are_never_markup(self):
        hostile = '<script>alert("x")</script><img src=x onerror=alert(1)> & "quoted" \'single\''
        self.tool("set-text", "Corpus_Sites", "shrine.intro", hostile)
        self.tool("set-text", "Corpus_Sites", "shrine.bless", "</span><script>1</script> {price}")
        self.tool("set-text", "Corpus_Sites", "shrine.log", "<b>bold</b> {price}")
        self.tool("set-info", "Corpus_Sites", "--name", "<i>Places</i> & more", "--description", "</title><script>2</script>")
        sites = self.sites()
        sites["sites"]["shrine"]["name"] = "<u>Shrine</u>"
        (self.folder / "sites.json").write_text(json.dumps(sites), encoding="utf-8")
        page = self.page("Corpus_Sites")
        self.assertNotRegex(page, r"(?i)<script|<img src=x|<u>|<i>|<b>bold|</title><")
        self.assertIn("&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;&lt;img src=x onerror=alert(1)&gt; &amp; &quot;quoted&quot; &#x27;single&#x27;", page)
        self.assertIn("<title>&lt;i&gt;Places&lt;/i&gt; &amp; more · preview</title>", page)
        self.assertIn("&lt;u&gt;Shrine&lt;/u&gt;", page)
        self.assertIn(hostile, words_of(page), "and read as the words they are")
        self.assertEqual(page.count("<main>"), 1)
        self.assertLessEqual(set(re.findall(r"<([a-zA-Z0-9]+)", page)),
                             {"html", "head", "meta", "title", "style", "body", "main", "h1", "h2", "h3", "p", "code", "span",
                              "b", "div", "img", "section"}, "no tag but the page's own")
        self.assertEqual(len(re.findall(r"<img ", page)), 2, "the two panes' pictures, no other")

    def test_every_pane_line_and_button_with_its_when_and_what_it_does(self):
        den = words_of(self.page(str(PLUGINS / "Gamblers_Den")))
        for wanted in ("pane 0 shown when: bet used up", "pane 1 shown otherwise", "pane 2 · id rules opened by the button rules",
                       "shown when: counter den_plays is 1 or more Odo keeps the tally on his remaining fingers: you have thrown 0 times.",
                       "Throw the dice (50 gold, 5 left) pays 50 gold, 5 times in all; counter den_plays +1, rolls: 3 in 6 nothing, "
                       "2 in 6 +75 gold, 1 in 6 +150 gold",
                       "then says: You lay 50 gold on the felt. The cup turns over.",
                       "then says (outcome 3): Three sixes.",
                       "shown when: counter den_plays is 3 or more Sit at the high table (200 gold, 2 left)",
                       "1 in 5 +300 gold, +1 red amulet", "Ask how the game is played free, any number of times; opens the pane rules",
                       "Leave closes the pane", "Flags: none. Counters: den_plays.",
                       "a hero named Hero who carries 1000 gold, 10 food and 2 amulets on day 12"):
            self.assertIn(wanted, den)
        ring = words_of(self.page(str(PLUGINS / "Duelists_Ring")))
        for wanted in ("Wager 50 gold against Marda Ironhand (3 left) stakes 50 gold, 3 times in all; duel Marda Ironhand (20 life); "
                       "win: +100 gold, counter ring_wins +1; lose: nothing",
                       "then says (win): The crowd roars. Marda Ironhand spits, laughs, and pays you 100 gold.",
                       "then says (lose): Marda Ironhand pockets your wager",
                       "Opponents", "Brannoch the Ringmaster ringmaster 25 The Ringmaster's Own, 40 cards: 9 Forest, 9 Plains"):
            self.assertIn(wanted, ring)
        camp = words_of(self.page(str(PLUGINS / "Wandering_Collector")))
        self.assertIn("shown when: holds Ornithopter Hand over Ornithopter for 150 gold (3 left) pays nothing, 3 times in all; "
                      "takes the card Ornithopter; +150 gold, counter wagon_trades +1", camp)
        self.assertIn("pays nothing, once; +1 blue amulet, +4 food", camp)
        stone = words_of(self.page(str(PLUGINS / "Riddle_Stone")))
        self.assertIn("shown when: counter stone_tries is 2 or more, not flag stone_solved Put your ear to the stone", stone)
        self.assertIn("pane 0 shown when: flag stone_solved", stone)

    def test_every_word_of_the_schema_has_plain_words(self):
        schema = self.game.schema()["types"]
        rows = ap.cheat_rows(self.game)
        self.assertEqual(len(rows["conditions"]), len(schema["sites_condition"]["options"]))
        for name, value, _, _, _ in rows["conditions"]:
            self.assertNotRegex(ap.condition_words(value), r"[{}\[\]]", name)
        file = {"dungeons": {"vault": {"name": "The Vault"}}, "sites": {}, "foes": {}}
        for name, value, _, _, _ in rows["effects"]:
            said = ap.effect_words(value, file, lambda key: "words")
            self.assertNotRegex(said, r"[{}\[\]]", name)
            self.assertNotIn(name + " ", said if "_" in name else "", name)
        self.assertEqual(ap.when_words([{"flag": "told"}, {"gold_at_least": 500}]), "flag told, gold ≥ 500")
        self.assertEqual(ap.condition_words({"any": [{"hero_color": "red"}, {"amulets": {"color": "red", "min": 2}}]}),
                         "one of (the hero is red; amulets (red) ≥ 2)")
        self.assertEqual(ap.condition_words({"used": {"action": "bless", "min": 1, "max": 2}}), "bless done 1 to 2")
        self.assertEqual(ap.effect_words({"teleport": {"to": "start"}}, file, str), "carries the hero to where the journey began")
        self.assertEqual(ap.effect_words({"spawn_dungeon": "vault"}, file, str), "raises the dungeon The Vault")

    def test_the_whole_of_api_three_dungeons_tasks_and_one_place_alone(self):
        case = next(c for c in corpus()["cases"] if c["name"] == "good_sites_api3_every_word")
        path = build_case(case, self.work, "Every")
        page = words_of(self.page(str(path)))
        for wanted in ("Dungeons", "The Den Vault vault random, small none Lightning Bolt 6 to 24 tiles", "Tasks rows",
                       "The den beat_keeper Beat the keeper of the den. The keeper is beaten. The Den",
                       "one of these, in turn the next one each time a button of the place is used",
                       "sells the hero a card: Lightning Bolt for 120 gold, Llanowar Elves for 0 gold; 2 of each",
                       "buys a card the hero holds: Gray Ogre for 15 gold",
                       "teaches the World Magic Dwarven Pick, links the nearest town's mana to the hero, +2 life in every duel "
                       "from now on, carries the hero to Wayside Shrine", "counted when won",
                       "the player’s skin draws visit_wiseman", "pane 2 · id back_room opened by the buttons ask and bribe, while: day ≥ 0"):
            self.assertIn(wanted, page)
        one = self.page(str(path), "--site", "shrine")
        self.assertNotIn("The Den", words_of(one).replace("The Den Vault", ""))
        self.assertNotIn("Tasks rows", one)
        self.assertEqual(sorted(p.name for p in (self.work / "out").iterdir()), ["corpus_sites_shrine.html"])
        zipped = self.work / "dist"
        self.tool("export", "Corpus_Sites", "--out", str(zipped))
        self.assertEqual(self.page(str(zipped / "Corpus_Sites.zip")), self.page("Corpus_Sites"), "a zip previews as its folder")

    def test_a_big_picture_is_named_not_embedded(self):
        import random
        noise = random.Random(7)
        big = ap.png_bytes(512, 280, [[(noise.randrange(256), noise.randrange(256), noise.randrange(256), 255)
                                       for _ in range(512)] for _ in range(280)])
        self.assertGreater(len(big), ap.PREVIEW_EMBED)
        (self.folder / "art" / "corpus_sites_shrine.png").write_bytes(big)
        page = self.page("Corpus_Sites")
        self.assertIn('<img alt="art/corpus_sites_shrine.png" src="../Corpus_Sites/art/corpus_sites_shrine.png">', page)
        self.assertLess(len(page), 20000)
        self.tool("export", "Corpus_Sites", "--out", "dist")
        zipped = self.page("dist/Corpus_Sites.zip")
        self.assertNotIn("<img", zipped)
        self.assertIn("art/corpus_sites_shrine.png (", zipped)
        self.assertIn("too big to put into this page", zipped)

    def test_preview_refuses_what_it_cannot_show(self):
        island = self.tool("preview", str(FIXTURES / "good_minimal"), ok=False)
        self.assertEqual(island.returncode, 2)
        self.assertIn("is an island plugin: preview shows a sites plugin's places.", island.stderr)
        self.assertEqual(self.tool("preview", "Corpus_Sites", "--site", "nowhere", ok=False).returncode, 2)
        inside = self.tool("preview", "Corpus_Sites", "--out", "Corpus_Sites/preview", ok=False)
        self.assertEqual(inside.returncode, 2)
        self.assertIn("--out must be outside the plugin folder", inside.stderr)
        self.assertFalse((self.folder / "preview").exists())
        (self.folder / "text.json").unlink()
        refused = self.tool("preview", "Corpus_Sites", ok=False)
        self.assertEqual((refused.returncode, refused.stdout.splitlines()[0]), (1, "text.json is missing."))
        self.assertFalse((self.work / "preview").exists())


class Wizard(Work):
    def wizard(self, answers: str, *args, ok: bool = True):
        (self.work / "answers.txt").write_text(answers, encoding="utf-8")
        return self.tool("wizard", *args, "--answers", "answers.txt", ok=ok)

    def test_a_new_plugin_from_a_few_answers(self):
        done = self.wizard("Roadside Things\nAnn\nThe Bone Cup\ngambler\n20\n3\n2\n\n")
        for wanted in ("What is your plugin called?", "What kind of place is it?", "   5. gambler ",
                       "The gold a throw costs. [50]", "Where does it stand?", "Write it now?",
                       "Done: wrote Roadside_Things. The place bone_cup (The Bone Cup) is the recipe gambler, on every island.",
                       "add-place Roadside_Things --id bone_cup --name 'The Bone Cup' --recipe gambler --where islands "
                       "--set price=20 --set throws=3",
                       "Checked as the game checks it: valid, with 3 warnings",
                       "Walked without the game: 2 panes shown, 3 buttons pressed; everything reached.",
                       "preview Roadside_Things", "set-text Roadside_Things bone_cup.intro", "export Roadside_Things --out dist",
                       "wizard Roadside_Things "):
            self.assertIn(wanted, done.stdout)
        result = ap.judge(str(self.work / "Roadside_Things"), self.game)
        self.assertTrue(result["valid"], result["problems"])
        manifest, sites = result["manifest"], result["data"]["sites"]
        self.assertEqual((manifest["id"], manifest["name"], manifest["authors"], manifest["api_version"],
                          ap.compare_versions(manifest["minimum_game_version"], ap.SITES_WORDS_GAME) >= 0), ("roadside_things", "Roadside Things", ["Ann"], 3, True))
        self.assertEqual(list(sites["sites"]), ["bone_cup"], "the skeleton's shrine is gone")
        bet = ap._site_actions(sites["sites"]["bone_cup"])["bet"]
        self.assertEqual((bet["prices"], sites["sites"]["bone_cup"]["where"]), ([20, 20, 20], ["islands"]))
        self.assertEqual([o["effects"] for o in bet["effects"][1]["roll"]["outcomes"]], [[], [{"gold": 30}], [{"gold": 60}]])
        self.assertIn("\"20 gold a throw,\"", result["data"]["text"]["bone_cup.offer"])
        self.assertFalse([p for p in self.work.iterdir() if p.name.endswith(".part")], "nothing of its building is left")
        # The commands it printed make the same plugin.
        again = self.work / "again"
        again.mkdir()
        import shlex
        for line in [l.strip() for l in done.stdout.splitlines() if l.startswith("    python3 tools/adventure_plugin.py ")][:3]:
            self.assertEqual(run_tool(*shlex.split(line)[2:], cwd=again).returncode, 0, line)
        for rel in ("plugin.json", "sites.json", "text.json"):
            self.assertEqual((again / "Roadside_Things" / rel).read_bytes(), (self.work / "Roadside_Things" / rel).read_bytes(), rel)

    def test_every_default_and_a_place_added_to_a_plugin(self):
        first = self.wizard("")
        self.assertIn("Done: wrote My_Places. The place old_inn (The Old Inn) is the recipe lore, on the mainland.", first.stdout)
        added = self.wizard("The Ring\n8\nBig Olaf\n2\n\n\n\n\nboth\nyes\n", "My_Places")
        self.assertIn("Adding a place to My_Places (plugin my_places, its places: old_inn).", added.stdout)
        self.assertIn("   2. green      40 cards: Llanowar Elves, Grizzly Bears, Scryb Sprites, ...", added.stdout)
        self.assertIn("Done: added to My_Places. The place ring (The Ring) is the recipe duelist, on the mainland and every island.",
                      added.stdout)
        self.assertIn("--recipe duelist --where mainland,islands --set 'foe=Big Olaf' --set deck=green", added.stdout)
        sites = ap.judge(str(self.work / "My_Places"), self.game)["data"]["sites"]
        self.assertEqual(list(sites["sites"]), ["old_inn", "ring"])
        foe = next(iter(sites["foes"].values()))
        self.assertEqual((foe["name"], foe["deck"], foe["life"]), ("Big Olaf", ap.STOCK_DECKS["green"], 20))
        twice = self.wizard("The Ring\nlore\n", "My_Places")
        self.assertIn("The place ring2 (The Ring)", twice.stdout, "a key already taken gets a number")
        named = self.wizard("Shrines of the North\n\nThe Gate\ntoll\n", "North")
        self.assertIn("Done: wrote North.", named.stdout)
        self.assertEqual(ap.judge(str(self.work / "North"), self.game)["manifest"]["id"], "shrines_of_the_north")

    def test_every_recipe_through_the_wizard_with_its_defaults(self):
        for n, recipe in enumerate(ap.RECIPES, 1):
            with self.subTest(recipe=recipe):
                done = self.wizard("Plugin %d\n\nThe %s\n%d\n" % (n, recipe.title(), n))
                self.assertIn("is the recipe %s, on the mainland." % recipe, done.stdout)
                self.assertIn("Checked as the game checks it: valid", done.stdout)
                for name, _, _, question in ap.RECIPE_OPTIONS.get(recipe, []):
                    self.assertIn(question, done.stdout, name)
                self.assertNotIn("--set", done.stdout, "every default: nothing to set")
        self.assertEqual(sorted(ap.RECIPE_OPTIONS), sorted(set(ap.RECIPES) - {"lore"}))
        for deck, cards in ap.STOCK_DECKS.items():
            self.assertEqual(sum(cards.values()), 40, deck)
            self.assertFalse([card for card in cards if not self.game.card_known(card, [])], deck)

    def test_leaving_and_wrong_answers_write_nothing(self):
        before = sorted(p.name for p in self.work.iterdir())
        for answers, code, wanted in (("Things\nq\n", 1, "Left the wizard; nothing was written."),
                                      ("Things\n\nA Place\nlore\n\nno\n", 1, "Left the wizard; nothing was written."),
                                      ("Things\n\nA Place\n99\n", 2, "wizard: answer 4 (99) does not fit \"What kind of place is it?\": "
                                                                    "Answer with a number from 1 to 12."),
                                      ("Things\n\nA Place\ngambler\nlots\n", 2, "a whole number from 0 to 100000 is needed"),
                                      ("Things\n\nA Place\ncollector\nLlanowar Elfs\n", 2, "is not a card of the base game; did you mean Llanowar Elves?"),
                                      ("Things\n\n" + "x" * 61 + "\n", 2, "A place's name is 1 to 60 characters.")):
            result = self.wizard(answers, ok=False)
            self.assertEqual(result.returncode, code, result.stdout + result.stderr)
            self.assertIn(wanted, result.stdout + result.stderr)
            self.assertEqual(sorted(p.name for p in self.work.iterdir()), before + ["answers.txt"] if "answers.txt" not in before else before)
        snapshot = self.snapshot()
        self.assertEqual(self.wizard("The Mill\nq\n", "Corpus_Sites", ok=False).returncode, 1)
        self.assertEqual(self.snapshot(), snapshot, "an existing plugin is untouched too")
        island = self.wizard("", str(FIXTURES / "good_minimal"), ok=False)
        self.assertEqual(island.returncode, 2)
        self.assertIn("is an island plugin", island.stderr)
        (self.work / "notes.txt").write_text("mine", encoding="utf-8")
        taken = self.wizard("notes.txt\n", ok=False)
        self.assertEqual(taken.returncode, 0, "a plugin named after a file gets a folder of its own name")
        self.assertTrue((self.work / "notes_txt").is_dir())

    def test_it_never_waits_for_a_terminal_that_is_not_there(self):
        result = subprocess.run([sys.executable, "-I", str(SCRIPT), "wizard"], stdin=subprocess.DEVNULL, capture_output=True,
                                text=True, encoding="utf-8", timeout=30, cwd=str(self.work))
        self.assertEqual(result.returncode, 2)
        self.assertIn("wizard asks its questions at a terminal, and this is none", result.stderr)
        self.assertIn("--answers FILE", result.stderr)
        self.assertEqual(result.stdout, "")
        piped = subprocess.run([sys.executable, "-I", str(SCRIPT), "wizard"], input="My Plugin\n", capture_output=True,
                               text=True, encoding="utf-8", timeout=30, cwd=str(self.work))
        self.assertEqual(piped.returncode, 2, "a pipe is no terminal either")
        missing = self.tool("wizard", "--answers", "nowhere.txt", ok=False)
        self.assertEqual(missing.returncode, 2)
        self.assertEqual(sorted(p.name for p in self.work.iterdir()), ["Corpus_Sites"])

    def test_a_plugin_that_is_full_is_said_before_any_question(self):
        for n in range(7):
            self.tool("add-place", "Corpus_Sites", "--id", "p%d" % n, "--name", "P", "--service", "none")
        full = self.wizard("", "Corpus_Sites", ok=False)
        self.assertEqual(full.returncode, 2)
        self.assertIn("already has eight places", full.stderr)


class RecipeOptions(Work):
    def test_set_changes_a_recipes_numbers_and_its_sentences(self):
        self.tool("add-place", "Corpus_Sites", "--id", "ring", "--name", "The Ring", "--recipe", "duelist", "--set", "foe=Big Olaf",
                  "--set", "deck=black", "--set", "wager=75", "--set", "prize=200", "--set", "bouts=2", "--set", "life=12")
        sites, text = self.sites(), self.text()
        duel = ap._site_actions(sites["sites"]["ring"])["duel"]
        self.assertEqual((duel["prices"], duel["win"]["effects"][0]), ([75, 75], {"gold": 200}))
        self.assertEqual(sites["foes"]["ring_champ"], {"name": "Big Olaf", "deck_name": "Big Olaf's Deck", "life": 12, "face": 3,
                                                       "deck": ap.STOCK_DECKS["black"]})
        self.assertIn("\"75 gold says you cannot beat me. Win, and you take 200. 2 bouts, no more.\"", text["ring.offer"])
        self.tool("add-place", "Corpus_Sites", "--id", "camp", "--name", "Camp", "--recipe", "collector", "--set", "card=Ornithopter",
                  "--set", "pay=90", "--set", "copies=2")
        trade = ap._site_actions(self.sites()["sites"]["camp"])["trade"]
        self.assertEqual((trade["prices"], trade["needs"], trade["effects"][0]), ([0, 0], [{"card": "Ornithopter"}], {"gold": 90}))
        self.tool("add-place", "Corpus_Sites", "--id", "tent", "--name", "Tent", "--recipe", "healer", "--set", "prices=10,20")
        self.assertEqual(ap._site_actions(self.sites()["sites"]["tent"])["bless"]["prices"], [10, 20])
        self.assertEqual(self.warnings().count("x"), 0)
        before = self.snapshot()
        for args, wanted in ((["--recipe", "gambler", "--set", "stake=5"], "The recipe gambler has no stake (it has: price, throws)."),
                             (["--recipe", "lore", "--set", "price=5"], "The recipe lore has no price (it has: nothing to set)."),
                             (["--recipe", "gambler", "--set", "throws=40"], "a whole number from 1 to 16 is needed"),
                             (["--recipe", "gambler", "--set", "price"], "--set takes NAME=VALUE"),
                             (["--recipe", "duelist", "--set", "deck=purple"], "one of red, green, white, blue, black is needed"),
                             (["--recipe", "traveler", "--set", "to=moon"], "one of nearest_town, start is needed")):
            refused = self.tool("add-place", "Corpus_Sites", "--id", "x", "--name", "X", *args, ok=False)
            self.assertEqual(refused.returncode, 2, args)
            self.assertIn(wanted, refused.stderr)
        self.assertEqual(self.snapshot(), before)
        # A gambler's prizes follow the price: a throw pays back its price on average, whatever it is.
        for price in (1, 7, 50, 333):
            parts = ap.place_recipe("gambler", "g", "G", options={"price": price})
            roll = parts["panes"][1]["actions"][0]["effects"]
            self.assertLessEqual(ap.SiteWalk.gold_of(roll), price)


class LaterWords(Work):
    def test_the_traveler_carries_and_the_teacher_teaches(self):
        self.tool("add-place", "Corpus_Sites", "--id", "cart", "--name", "The Cart", "--recipe", "traveler")
        self.tool("add-place", "Corpus_Sites", "--id", "mage", "--name", "The Mage", "--recipe", "teacher", "--set", "magic=Quickening")
        self.assertEqual([w for w in self.warnings() if "stand-in" not in w], [])
        ride = self.tool("walk", "Corpus_Sites", "--site", "cart", "--gold", "250").stdout
        self.assertIn('Press "Ride to the nearest town (100 gold)": 0 gold paid, 150 left; ride used 1 time', ride)
        self.assertIn("     the pane closes; the hero is carried to the nearest town (the walk steps back in)", ride)
        self.assertIn("  End: 50 gold; uses cart.ride 2;", ride)
        poor = self.tool("walk", "Corpus_Sites", "--site", "cart", "--gold", "50").stdout
        self.assertIn("the button ride was never shown: its when is [{\"gold_at_least\": 100}]", poor)
        taught = self.tool("walk", "Corpus_Sites", "--site", "mage", "--gold", "2000").stdout
        for line in ('Press "Learn Quickening (800 gold)": 800 gold paid, 1200 left; learn used 1 time',
                     "     World Magic learned: Quickening", "     journal: Bought WM: Quickening",
                     "     life at the start of every duel: +3 now",
                     "You will begin every duel with 3 more life than before you met the mage.",
                     "  End: 300 gold; uses mage.learn 1, mage.lesson 3; flags none; dungeons none; World Magics Quickening; life bonus +3."):
            self.assertIn(line, taught)
        knows = self.tool("walk", "Corpus_Sites", "--site", "mage", "--gold", "2000", "--magics", "Quickening, Dwarven Pick",
                          "--life-bonus", "9").stdout
        self.assertIn("The mage opens one eye. \"Quickening is yours already. That lesson is done.\"", knows)
        self.assertIn("( ) Learn Quickening (800 gold)   not ready: Quickening is yours already.", knows)
        self.assertIn("\"The long breath has given you 9 more life so far.", knows)
        self.assertIn("life bonus +10.", knows)
        self.assertIn("the button learn was shown but never ready: Quickening is yours already.", knows)
        start = ap.place_recipe("traveler", "cart", "The Cart", options={"to": "start", "fare": 30})
        self.assertEqual(start["panes"][0]["actions"][0]["effects"], [{"gold": -30}, {"teleport": {"to": "start"}}])
        self.assertEqual(start["words"]["cart.ride"], "Ride to where your journey began (30 gold)")

    def test_what_cannot_be_done_is_refused_before_anything_is_paid(self):
        self.tool("add-place", "Corpus_Sites", "--id", "post", "--name", "The Post", "--where", "islands", "--service", "none")
        self.tool("add-dungeon", "Corpus_Sites", "--id", "vault", "--name", "The Vault", "--cards", "Swamp")
        for name, effect in (("link", "mana_link=nearest_town"), ("grow", "life_bonus=3"), ("learn", "world_magic=Leap of Fate"),
                             ("far", "teleport=place:post"), ("deep", "teleport=dungeon:vault"), ("home", "teleport=start")):
            self.tool("add-action", "Corpus_Sites", "--place", "shrine", "--id", name, "--prices", "10,10,10,10", "--effect", effect,
                      "--label", name.title() + " ({price} gold)")
        actions = ap._site_actions(self.sites()["sites"]["shrine"])
        self.assertEqual([actions[n]["effects"] for n in ("link", "grow", "learn", "far")],
                         [[{"mana_link": "nearest_town"}], [{"life_bonus": 3}], [{"world_magic": "Leap of Fate"}],
                          [{"teleport": {"to": "place:post"}}]])
        data = self.judged()["data"]
        hero = ap.walk_hero(data, 1000, {"life_bonus": 8})
        self.assertEqual((hero.press("shrine", "link")["linked"], hero.linked), ("the nearest town", True))
        again = hero.press("shrine", "link")
        self.assertEqual((again["refused"], again["paid"]), ("No town of this land can be linked now.", 0))
        self.assertEqual((hero.press("shrine", "grow")["life_bonus"], hero.life_bonus), (10, 10), "ten at most")
        self.assertEqual(hero.press("shrine", "grow")["refused"], "No place can add to your life any more.")
        self.assertEqual(hero.press("shrine", "learn")["learned"], ["Leap of Fate"])
        self.assertEqual(hero.press("shrine", "learn")["refused"], "Leap of Fate is yours already.")
        self.assertEqual(hero.press("shrine", "far")["refused"], "There is no way there from here.", "the post stands on islands only")
        self.assertEqual(hero.press("shrine", "deep")["refused"], "There is no way there from here.", "the vault is not raised")
        self.assertEqual(hero.press("shrine", "home")["carried"], "where the journey began")
        hero.mainland = False
        self.assertEqual(hero.press("shrine", "far")["carried"], "The Post")
        hero.dungeons["vault"] = "open"
        self.assertEqual(hero.press("shrine", "deep")["carried"], "The Vault")
        self.assertEqual(hero.gold, 1000 - 60)
        self.assertTrue(hero.holds("shrine", [{"town_linked": "nearest_town"}]))
        self.assertFalse(hero.holds("shrine", [{"life_bonus_below": 10}]))
        linked = ap.walk_hero(data, 0, {"linked": True, "life_bonus": 2})
        self.assertEqual((linked.linked, linked.values("shrine")["life_bonus"]), (True, 2))
        self.assertEqual(ap.walk_hint([{"town_linked": "nearest_town"}]), " (try --linked)")

    def test_town_and_title_are_filled_where_their_action_stands_and_warned_of_elsewhere(self):
        self.tool("add-action", "Corpus_Sites", "--place", "shrine", "--id", "learn", "--prices", "10", "--effect",
                  "world_magic=Leap of Fate", "--label", "Learn {title}", "--result", "{title} is yours; {life_bonus} life so far.")
        self.tool("add-action", "Corpus_Sites", "--place", "shrine", "--id", "ride", "--effect", "teleport=nearest_town",
                  "--label", "Ride to {town}")
        self.assertEqual([w for w in self.warnings() if "{" in w], [])
        hero = ap.walk_hero(self.judged()["data"], 100)
        labels = {b["id"]: b["label"] for b in hero.describe("shrine")["buttons"]}
        self.assertEqual((labels["learn"], labels["ride"]), ("Learn Leap of Fate", "Ride to the nearest town"))
        self.assertEqual(hero.press("shrine", "learn")["lines"], ["Leap of Fate is yours; 0 life so far."])
        self.tool("set-text", "Corpus_Sites", "shrine.intro", "{town} is near; {title} is taught.")
        said = "\n".join(self.warnings())
        self.assertIn("text.json: shrine.intro: {town} is filled in an island plugin's texts only", said)
        self.assertIn("text.json: shrine.intro: {title} is filled in an island plugin's texts only", said)

    def test_the_cheat_sheet_and_the_page_name_them(self):
        schema = self.game.schema()
        self.assertLessEqual({"world_magic", "mana_link", "life_bonus", "teleport"}, set(schema["v3_words"]["effect"]))
        self.assertLessEqual({"life_bonus_below", "town_linked"}, set(schema["v3_words"]["condition"]))
        cheat = (PLUGINS / "GUIDE" / "cheatsheet.html").read_text(encoding="utf-8")
        sites = (PLUGINS / "GUIDE" / "sites.html").read_text(encoding="utf-8")
        for word in ("world_magic", "mana_link", "life_bonus", "teleport", "life_bonus_below", "town_linked"):
            self.assertIn("<code>%s</code>" % word, cheat)
            self.assertIn("<code>%s</code>" % word, sites)
        for form in ('--effect "teleport=nearest_town"', '--effect "life_bonus=1"', '--when "town_linked=nearest_town"',
                     "{life_bonus}", "{town}", "{title}", "wizard My_Places --answers answers.txt", "preview My_Places"):
            self.assertIn(html.escape(form), cheat, form)
        plain = html.unescape(re.sub(r"<[^>]+>", "", sites))
        for wanted in ("Start here: the wizard", "python3 tools/adventure_plugin.py wizard", "python3 tools/adventure_plugin.py preview My_Places",
                       "site.no_way", "site.magic_owned", "site.no_link", "site.life_full", "--set NAME=VALUE", "--life-bonus N",
                       "--linked", '--magics "A,B"', "one of twelve kinds"):
            self.assertIn(wanted, plain, wanted)
        self.assertLess(sites.index('id="wizard"'), sites.index('<h2 id="what">'), "the wizard comes first")
        source = (ROOT / "game/adventure/plugins/data_sites.gd").read_text(encoding="utf-8")
        for line in ('"life_bonus_below": return player.life_bonus < int(value)', 'return say("site.magic_owned", {"title": value})',
                     'return say("site.no_link")', 'return say("site.life_full")', 'return say("site.no_way")',
                     "player.life_bonus = clampi(player.life_bonus + int(value), 0, AdventurePlayer.LIFE_BONUS_MOST)"):
            self.assertIn(line, source, "DataSites no longer says: " + line)
        self.assertIn("const LIFE_BONUS_MOST := %d" % ap.MOST_LIFE_BONUS,
                      (ROOT / "game/adventure/adventure_player.gd").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
