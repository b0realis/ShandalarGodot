extends GutTest
## PLACES, API 3 (the places campaign of 2026-11-22; the owner: *"make it
## easy to create new places that give additional context and users can
## make do various game mechanics"*): the seven faults found in the sites
## plugins, and every new word — conditions, effects, the `needs` cost, talk
## panes, a roll on the plugin's own dice, duels, card trades, tasks — on
## the model side. A places plugin stays data: every test here feeds JSON.

const INN := preload("res://tests/support/c1122_places_fixture.gd")
const BEACON := preload("res://tools/expansion_testing/beacon_region.gd")
const ROOT := "user://c1122_places_tests"


func before_each() -> void:
	INN.install(ROOT, INN.sites())
	AdventurePlugins.folders_override = [ROOT] as Array[String]
	AdventurePlugins.scan()


func after_each() -> void:
	AdventureExpansions.clear_development()
	INN.remove(ROOT)
	AdventurePlugins.folders_override = [] as Array[String]
	AdventurePlugins.scan()


func hero(lands: Array[String] = ["inn"], seed_text := "48271") -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = seed_text
	setup.adventures = lands
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(player)
	return player


func inn() -> DataSites:
	return AdventureSites.provider("inn")


func _hold(player: AdventurePlayer, cards: Array) -> void:
	player.cards = []
	for card: String in cards:
		player.cards.append({"card": card, "decks": [0]})
	player.current_deck = 0


func _button(pane: Dictionary, tail: String) -> Array:
	for action: Array in pane.get("actions", []):
		if String(action[0]).ends_with(tail):
			return action
	return []


func _has_problem(problems: Array, part: String) -> bool:
	for problem: String in problems:
		if part in problem:
			return true
	gut.p("problems: " + "\n".join(problems))
	return false


func _root(content: Dictionary) -> Dictionary:
	return content["sites"]["inn"]["panes"][3]


# ------------------------------------------------------------- loading --

func test_the_inn_is_a_valid_plugin_of_api_3() -> void:
	assert_true(AdventurePlugins.valid("inn"), AdventurePlugins.refusal("inn"))
	assert_eq(INN.problems(INN.sites()), [])
	assert_eq(AdventurePlugins.API_VERSION, 3)
	assert_eq(int(PluginSchema.schema()["api_version"]), 3)


func test_a_version_2_plugin_with_a_version_3_word_is_refused_by_the_word() -> void:
	var problems := INN.problems(INN.sites(), 2)
	for word in ["counters", "foes", "tasks", "id", "one_of", "talk", "duel", "buy_card", "sell_card", "needs", "roll",
			"next_duel", "reveal_map", "give_card", "amulet", "counter", "any", "hero_color", "has_card", "to", "foe", "win", "count", "cards", "stock"]:
		assert_true(_has_problem(problems, "\"%s\" is a word of plugin API 3, and plugin.json declares api_version 2." % word), word)
	var once := problems.filter(func(problem: String) -> bool: return "\"counter\" is a word" in problem)
	assert_eq(once.size(), 1, "each word named once")
	assert_string_contains(String(once[0]), "Set \"api_version\": 3 there")


func test_every_condition_and_effect_of_api_3_is_listed_for_the_gate() -> void:
	var spec := PluginSchema.schema()
	var listed: Dictionary = spec["v3_words"]
	var old_conditions := ["flag", "not_flag", "gold_at_least", "on_mainland", "used", "used_up", "dungeon"]
	var old_effects := ["set_flag", "clear_flag", "gold", "food", "log_clue", "log_event", "spawn_dungeon"]
	var conditions: Array = spec["types"]["sites_condition"]["options"].keys()
	var effects: Array = spec["types"]["sites_effect"]["options"].keys()
	assert_eq(conditions, old_conditions + (listed["condition"] as Array), "a condition is API 2's or gated")
	assert_eq(effects, old_effects + (listed["effect"] as Array), "an effect is API 2's or gated")
	assert_eq(spec["types"]["sites_action"]["fields"]["do"]["values"], ["effects", "copy_card", "leave"] + (listed["do"] as Array))
	assert_eq(spec["types"]["sites_condition"]["options"]["owns_magic"]["values"], AdventurePlayer.WORLD_MAGICS as Array)


func test_the_shipped_version_2_plugins_load_untouched() -> void:
	for folder in ["Old_Adventurers_Hut", "Conjuration_Wizard_Guild"]:
		var from := "res://expanded_adventure".path_join(folder)
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(from.path_join("plugin.json")))
		assert_eq(int(manifest["api_version"]), 2, folder)
		var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(from.path_join("sites.json")))
		var files := {"sites.json": FileAccess.get_file_as_bytes(from.path_join("sites.json")), "text.json": FileAccess.get_file_as_bytes(from.path_join("text.json"))}
		var pictures: Array = (content.get("pictures", {}) as Dictionary).values()
		for site: Dictionary in (content["sites"] as Dictionary).values():
			pictures.append(String(site["sprite"]["file"]))
		for rel: String in pictures:
			files[rel] = INN.picture()
		assert_eq(PluginSchema.read(manifest, files)["problems"], [], folder)


func test_an_unknown_api_is_refused_cleanly() -> void:
	# What a game that reads only API 2 says of an API 3 plugin, one API on.
	assert_has(AdventurePlugins.manifest_problems(INN.manifest(4)), "This plugin needs plugin API 4; this game reads API 3. A newer game is needed.")
	assert_eq(AdventurePlugins.manifest_problems(INN.manifest(3)), [] as Array[String])


# ------------------------------------------------- bug 1.3: no way out --

func test_a_place_needs_a_pane_to_open_on_and_every_pane_a_way_out() -> void:
	var content := INN.sites()
	_root(content)["when"] = [{"gold_at_least": 1000}]
	assert_true(_has_problem(INN.problems(content), "sites.inn.panes[3].when: the last pane without an id must have no when"))
	content = INN.sites()
	_root(content)["id"] = "front"
	assert_true(_has_problem(INN.problems(content), "sites.inn.panes: every pane has an id"))
	content = INN.sites()
	_root(content)["actions"].pop_back()
	assert_true(_has_problem(INN.problems(content), "sites.inn.panes[3].actions: a pane needs an action that does \"leave\" and has no when"))
	content = INN.sites()
	_root(content)["actions"][7]["when"] = [{"flag": "told"}]
	assert_true(_has_problem(INN.problems(content), "sites.inn.panes[3].actions: a pane needs an action that does \"leave\""), "a leave behind a when is no way out")
	content = INN.sites()
	content["sites"]["inn"]["panes"][0]["actions"] = []
	assert_true(_has_problem(INN.problems(content), "sites.inn.panes[0].actions: a pane needs"), "a talk's pane too")


# ----------------------------------------------- the checks of the words --

func test_what_a_word_names_must_exist() -> void:
	var cases := [
		[func(c: Dictionary) -> void: _root(c)["actions"][0]["to"] = "nowhere", "actions[0].to: this site has no pane with the id nowhere."],
		[func(c: Dictionary) -> void: _root(c)["actions"][0].erase("to"), "a talk needs \"to\""],
		[func(c: Dictionary) -> void: c["sites"]["inn"]["panes"][1]["id"] = "rumors", "panes[1].id: rumors is another pane's id"],
		[func(c: Dictionary) -> void: c["sites"]["inn"]["panes"][1]["actions"][3]["foe"] = "nobody", ".foe: no foe nobody in sites.json foes."],
		[func(c: Dictionary) -> void: c["foes"]["champion"]["deck"] = {"Forest": 40, "Swamp": 40, "Island": 40, "Plains": 40, "Mountain": 40, "Grizzly Bears": 40, "Black Lotus": 11}, "foes.champion.deck holds 251 cards; 1 to 250 are allowed."],
		[func(c: Dictionary) -> void: _root(c)["actions"][1]["effects"] = [{"counter": {"name": "nope", "add": 1}}], "no counter nope in sites.json counters."],
		[func(c: Dictionary) -> void: _root(c)["actions"][1]["effects"] = [{"counter": {"name": "visits", "add": 1, "set": 2}}], "one of add or set is needed"],
		[func(c: Dictionary) -> void: _root(c)["actions"][1]["effects"] = [{"counter": {"name": "visits"}}], "one of add or set is needed"],
		[func(c: Dictionary) -> void: _root(c)["actions"][5]["when"] = [{"counter": {"name": "nope"}}], "when[0].counter: no counter nope"],
		[func(c: Dictionary) -> void: _root(c)["actions"][5]["when"] = [{"site_used": {"site": "mill", "action": "ask"}}], "site_used: no place mill"],
		[func(c: Dictionary) -> void: _root(c)["actions"][5]["when"] = [{"site_used": {"site": "inn", "action": "nope"}}], "site_used: the place inn has no action nope."],
		[func(c: Dictionary) -> void: _root(c)["actions"][5]["when"] = [{"any": [{"any": [{"at_peace": true}]}]}], "no any inside an any"],
		[func(c: Dictionary) -> void: _root(c)["actions"][5]["when"] = [{"difficulty": {"min": 3, "max": 1}}], "difficulty: min 3 is more than max 1."],
		[func(c: Dictionary) -> void: _root(c)["actions"][5]["when"] = [{"owns_magic": "Sword of Plenty"}], "owns_magic"],
		[func(c: Dictionary) -> void: _root(c)["actions"][5]["when"] = [{"has_card": {"card": "No Such Card Anywhere"}}], "No Such Card Anywhere is not a card"],
		[func(c: Dictionary) -> void: _root(c)["actions"][3]["prices"] = [], "give_card: a card is given without end; give the action prices"],
		[func(c: Dictionary) -> void: _root(c)["actions"][4]["effects"] = [{"amulet": {"color": "red", "count": 1}}]; _root(c)["actions"][4]["needs"] = [], "amulet: amulets are given without end"],
		[func(c: Dictionary) -> void: _root(c)["actions"][5]["effects"] = [{"next_duel": {"life": 5, "first_move": true}}], "exactly one of life, first_move or card"],
		[func(c: Dictionary) -> void: _root(c)["actions"][5]["effects"] = [{"reveal_map": {"around": "dungeon:attic"}}], "reveal_map.around: no dungeon attic"],
		[func(c: Dictionary) -> void: c["sites"]["inn"]["panes"][1]["actions"][0]["effects"][0]["roll"]["outcomes"][0]["effects"] = [{"roll": {"outcomes": [{}, {}]}}], "no roll inside a roll's outcome."],
		[func(c: Dictionary) -> void: c["sites"]["inn"]["panes"][1]["actions"][3]["win"]["effects"] = [{"roll": {"outcomes": [{}, {}]}}], "no roll in a duel's win or lose"],
		[func(c: Dictionary) -> void: c["sites"]["inn"]["panes"][1]["actions"][0]["effects"].append({"roll": {"outcomes": [{}, {}]}}), "one roll an action"],
		[func(c: Dictionary) -> void: _root(c)["actions"][0]["cards"] = {"Forest": 5}, "cards: only an action that does buy_card or sell_card has cards."],
		[func(c: Dictionary) -> void: _root(c)["actions"][2]["foe"] = "champion", "foe: only an action that does duel has foe."],
		[func(c: Dictionary) -> void: c["sites"]["inn"]["panes"][2]["actions"][0]["prices"] = [5], "prices: only an action that does effects or talk or copy_card or duel has prices."],
		[func(c: Dictionary) -> void: c["sites"]["inn"]["panes"][2]["actions"][0]["cards"] = {}, "buy_card needs \"cards\""],
		[func(c: Dictionary) -> void: c["tasks"]["go_inn"]["at"] = "place:mill", "tasks.go_inn.at: no place mill"],
		[func(c: Dictionary) -> void: c["tasks"]["cellar"]["at"] = "dungeon:attic", "tasks.cellar.at: no dungeon attic"],
		[func(c: Dictionary) -> void: c["tasks"]["cellar"]["when"] = [{"used_up": "cellar"}], "used_up reads the place a task is at"],
		[func(c: Dictionary) -> void: c["counters"] = ["visits", "wins", "wins"], "counters[2]: wins is named twice."],
	]
	for case: Array in cases:
		var content := INN.sites()
		(case[0] as Callable).call(content)
		assert_true(_has_problem(INN.problems(content), String(case[1])), String(case[1]))


# ------------------------------------------------------------ conditions --

func test_the_new_conditions_read_the_hero() -> void:
	var player := hero()
	_hold(player, ["Forest", "Forest", "Grizzly Bears"])
	player.color = "green"
	player.amulets = {"black": 0, "blue": 1, "green": 2, "red": 0, "white": 0}
	player.food = 7
	player.gold = 99
	player.difficulty = 2
	player.journey_time = WorldStatus.DAY * 3 + 1
	var cases := [
		[{"has_card": {"card": "Forest", "min": 2}}, true], [{"has_card": {"card": "Forest", "min": 3}}, false],
		[{"has_card": {"card": "Black Lotus"}}, false],
		[{"amulets": {"color": "green", "min": 2}}, true], [{"amulets": {"color": "red"}}, false],
		[{"amulets": {"color": "any", "min": 3}}, true], [{"amulets": {"min": 4}}, false],
		[{"hero_color": "green"}, true], [{"hero_color": "red"}, false],
		[{"owns_magic": "Dwarven Pick"}, false],
		[{"food_at_least": 7}, true], [{"food_at_least": 8}, false],
		[{"gold_below": 100}, true], [{"gold_below": 99}, false],
		[{"day_at_least": 3}, true], [{"day_at_least": 4}, false],
		[{"wizards_defeated": 0}, true], [{"wizards_defeated": 1}, false],
		[{"at_peace": false}, true], [{"at_peace": true}, false],
		[{"difficulty": {"min": 1, "max": 2}}, true], [{"difficulty": {"max": 1}}, false],
		[{"plugin_on": "inn"}, true], [{"plugin_on": "not_installed"}, false],
		[{"counter": {"name": "wins", "max": 0}}, true], [{"counter": {"name": "wins", "min": 1}}, false],
		[{"site_used": {"site": "inn", "action": "gift"}}, false], [{"site_used": {"site": "inn", "action": "gift", "min": 0, "max": 0}}, true],
		[{"gift_waiting": false}, true], [{"gift_waiting": true}, false],
		[{"any": [{"hero_color": "red"}, {"food_at_least": 5}]}, true], [{"any": [{"hero_color": "red"}, {"food_at_least": 50}]}, false],
	]
	for case: Array in cases:
		assert_eq(inn().holds(player, "inn", [case[0]]), bool(case[1]), JSON.stringify(case[0]))
	player.world_magics.append("Dwarven Pick")
	player.defeated_wizards.append("red")
	player.next_duel_first_move = true
	player.ended = AdventurePlayer.ENDED_WON
	for condition: Dictionary in [{"owns_magic": "Dwarven Pick"}, {"wizards_defeated": 1}, {"gift_waiting": true}, {"at_peace": true}]:
		assert_true(inn().holds(player, "inn", [condition]), JSON.stringify(condition))


# ---------------------------------------------------------------- effects --

func test_a_gift_gives_a_card_amulets_and_sets_a_counter_once() -> void:
	var player := hero()
	_hold(player, ["Forest"])
	player.amulets["red"] = 98
	var gold := player.gold
	inn().do_effects(player, "inn", "gift")
	assert_eq(DataSites.held(player, "Grizzly Bears"), 1)
	assert_eq(int(player.amulets["red"]), 99, "never more than 99 of a color by a gift")
	assert_eq(inn().counter(player, "wins"), 5)
	assert_eq(player.gold, gold, "its price is 0")
	assert_eq(_button(inn().describe(player, "inn"), ":inn:gift"), [], "prices [0]: once")
	inn().do_effects(player, "inn", "gift")
	assert_eq(DataSites.held(player, "Grizzly Bears"), 1, "and never again")


func test_a_card_is_refused_before_anything_is_paid_when_the_bag_is_full_or_the_rules_forbid() -> void:
	var player := hero()
	player.card_hold = AdventurePlayer.HOLD_1997
	_hold(player, [])
	while player.bag_room() > 0:
		player.cards.append({"card": "Forest", "decks": []})
	var pane := inn().do_effects(player, "inn", "gift")
	assert_string_contains(String(pane["lines"][0]), "Your bag is full")
	assert_eq(inn().uses(player, "inn", "gift"), 0, "not counted")
	assert_eq(inn().counter(player, "wins"), 0, "none of its effects applied")
	assert_false(bool(_button(inn().describe(player, "inn"), ":inn:gift")[2]), "its button says so")
	player.cards.resize(4)
	player.card_rule = AdventurePlayer.RULE_CLASSIC
	for i in 4:
		player.cards.append({"card": "Grizzly Bears", "decks": []})
	pane = inn().do_effects(player, "inn", "gift")
	assert_string_contains(String(pane["lines"][0]), "You may hold no more copies of Grizzly Bears")
	assert_eq(inn().uses(player, "inn", "gift"), 0)


func test_a_gift_for_the_next_duel_is_given_once_and_refused_while_one_waits() -> void:
	var player := hero()
	player.gold = 200
	inn().do_effects(player, "inn", "bless")
	assert_eq(player.next_duel_life, 5)
	assert_eq(player.gold, 150)
	var pane := inn().do_effects(player, "inn", "bless")
	assert_string_contains(String(pane["lines"][0]), "A gift for your next duel already waits")
	assert_eq(player.gold, 150, "nothing paid for a gift that cannot be had")
	assert_eq(inn().uses(player, "inn", "bless"), 1)
	player.clear_duel_gifts()
	inn().do_effects(player, "inn", "bless")
	assert_eq(player.gold, 100)
	assert_eq(player.next_duel_life, 5)


func test_needs_take_a_card_amulets_and_food_or_refuse_before_paying() -> void:
	var player := hero()
	_hold(player, ["Forest", "Grizzly Bears"])
	player.cards.append({"card": "Forest", "decks": []})
	player.amulets = {"black": 1, "blue": 0, "green": 2, "red": 0, "white": 0}
	player.food = 2
	var gold := player.gold
	var button := _button(inn().describe(player, "inn"), ":inn:trade")
	assert_eq(String(button[1]), "Give Forest (it leaves your decks)", "the default label of an action that takes a card")
	assert_false(bool(button[2]))
	assert_string_contains(String(inn().do_effects(player, "inn", "trade")["lines"][0]), "You need 3 food for this; you carry 2.")
	assert_eq([player.gold, player.cards.size(), player.amulet_count()], [gold, 3, 3], "nothing taken")
	player.food = 10
	inn().do_effects(player, "inn", "trade")
	assert_eq(player.gold, gold + 40)
	assert_eq(player.food, 7)
	assert_eq(player.amulets, {"black": 0, "blue": 0, "green": 1, "red": 0, "white": 0}, "any: one at a time from the color there is most of, black first among equals")
	assert_eq(DataSites.held(player, "Forest"), 1)
	assert_eq((player.cards[0]["decks"] as Array).size(), 1, "the copy in no deck went first")
	assert_string_contains(String(inn().do_effects(player, "inn", "trade")["lines"][0]), "You need 2 amulets for this; you carry 1.")
	player.amulets["white"] = 5
	inn().do_effects(player, "inn", "trade")
	assert_eq(DataSites.held(player, "Forest"), 0, "the last copy leaves its deck")
	assert_string_contains(String(inn().do_effects(player, "inn", "trade")["lines"][0]), "You need Forest for this; you hold none.")


func test_the_map_is_uncovered_around_the_place() -> void:
	var player := hero()
	var point: Array = player.world.expansion[AdventureSites.KEY]["inn:inn"]
	var at := Vector2i(int(point[0]), int(point[1]))
	var far := at + Vector2i(3, 0)
	if player.world.is_explored(far.x, far.y):
		player.world.page[far.y * ShandalarWorld.PAGE_WIDTH + far.x] &= ~ShandalarWorld.EXPLORED
	inn().do_effects(player, "inn", "map")
	for step in [Vector2i(3, 0), Vector2i(0, -3), Vector2i(2, 2), Vector2i(0, 0)]:
		var tile: Vector2i = at + step
		if tile.x >= 0 and tile.y >= 0 and tile.x < 64 and tile.y < 64:
			assert_true(player.world.is_explored(tile.x, tile.y), str(step))


# ------------------------------------------------- bug 1.4: the journal --

func test_a_plugins_event_is_logged_under_its_own_name_and_forges_no_statistic() -> void:
	var player := hero()
	player.color = "red"
	var before := HeroStats.record(player)
	var record := player.duel_record()
	inn().do_effects(player, "inn", "gated")
	assert_true(inn().flag(player, "told"))
	var line: Dictionary = player.journal.back()
	assert_eq(String(line["event"]), "inn:duel", "never the game's own \"duel\"")
	assert_eq(player.duel_record(), record, "no lost duel counted")
	var after := HeroStats.record(player)
	for key in ["won", "lost", "saved", "recovered", "quests_done", "quests_failed", "treasures"]:
		assert_eq(after[key], before[key], key)
	assert_string_contains(HeroStats.journal_line(line, player), "A night at the inn.")
	# A line an older game wrote under the bare name is shown as it was.
	assert_string_contains(HeroStats.journal_line({"event": "old_hut", "text": "The old man told of a vault.", "day": 2}, player), "The old man told of a vault.")


# --------------------------------------- bugs 1.1, 1.6, 1.7: the dungeon --

func test_the_dungeon_placeholder_is_the_actions_own_and_never_left_bare() -> void:
	var player := hero()
	player.gold = 500
	var button := _button(inn().describe(player, "inn"), ":inn:cellar")
	assert_eq(String(button[1]), "The way to The Cellar (100 gold)", "named before it is raised")
	var told := inn().do_effects(player, "inn", "cellar")
	assert_eq(String(told["lines"][0]), "The way to The Cellar is yours.")
	assert_eq(inn().values(player, "inn").get("dungeon"), "The Cellar", "a pane's lines: the plugin's dungeon")


func test_nothing_is_paid_for_a_dungeon_that_is_open() -> void:
	var content := INN.sites()
	_root(content)["actions"][2]["prices"] = [100, 100]
	INN.install(ROOT, content)
	AdventurePlugins.scan()
	var player := hero()
	player.gold = 500
	inn().do_effects(player, "inn", "cellar")
	assert_eq(player.gold, 400)
	assert_eq(inn().dungeon_state(player, "cellar"), "open")
	var button := _button(inn().describe(player, "inn"), ":inn:cellar")
	assert_false(bool(button[2]), "its button is not ready")
	var pane := inn().do_effects(player, "inn", "cellar")
	assert_eq(String(pane["lines"][0]), "The Cellar still waits for you; there is nothing new to tell.")
	assert_eq(player.gold, 400, "nothing paid")
	assert_eq(inn().uses(player, "inn", "cellar"), 1, "no use spent")


func test_a_dungeon_sold_on_the_mainland_is_still_for_sale_on_an_island() -> void:
	assert_true(AdventureExpansions.register_development(BEACON.ID, BEACON.descriptor()))
	var player := hero([BEACON.ID, "inn"] as Array[String])
	player.gold = 500
	assert_true(inn().per_land("inn", "cellar"))
	assert_false(inn().per_land("inn", "gift"))
	inn().do_effects(player, "inn", "cellar")
	assert_eq(inn().uses(player, "inn", "cellar"), 1)
	assert_eq(_button(inn().describe(player, "inn"), ":inn:cellar"), [], "sold once on the mainland")
	assert_true(AdventureExpansions.voyage(player, BEACON.ID))
	AdventureExpansions.entered(player)
	assert_eq(inn().uses(player, "inn", "cellar"), 0, "the island's own count")
	assert_eq(inn().dungeon_state(player, "cellar"), "none")
	var button := _button(inn().describe(player, "inn"), ":inn:cellar")
	assert_false(button.is_empty(), "the button is there again")
	assert_true(bool(button[2]))
	inn().do_effects(player, "inn", "cellar")
	assert_eq(player.gold, 300)
	assert_eq(inn().dungeon_state(player, "cellar"), "open", "the island's own cellar")
	assert_eq(_button(inn().describe(player, "inn"), ":inn:cellar"), [])
	var read := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_eq(read.sites, player.sites, "a land's count is kept by the save")


func test_an_older_saves_count_is_read_for_the_land_that_holds_the_dungeon() -> void:
	var player := hero()
	player.gold = 500
	inn().do_effects(player, "inn", "cellar")
	# As 0.70.4 wrote it: one count for the plugin as a whole.
	var state: Dictionary = player.sites["inn"]
	state["uses"].erase("inn.cellar@mainland")
	state["uses"]["inn.cellar"] = 1
	assert_eq(inn().uses(player, "inn", "cellar"), 1, "the mainland holds the cellar: the count is its")
	assert_eq(_button(inn().describe(player, "inn"), ":inn:cellar"), [])
	state["dungeons"].clear()
	assert_eq(inn().uses(player, "inn", "cellar"), 0, "a land without the dungeon did not pay for it")


# ------------------------------------------------------- talk and lines --

func test_a_talk_opens_its_pane_and_a_plain_one_saves_nothing() -> void:
	var player := hero()
	player.gold = 100
	var before := JSON.stringify(player.sites)
	var pane := inn().describe(player, "inn")
	assert_eq(String(pane["pane"]), "", "a pane with an id is never chosen by itself")
	assert_string_contains(String(pane["lines"][0]), "you carry %d food and %d amulets" % [player.food, player.amulet_count()])
	assert_eq(String(_button(pane, ":inn:ask")[1]), "Ask")
	var rumors := inn().do_effects(player, "inn", "ask")
	assert_eq(String(rumors["pane"]), "rumors")
	assert_eq(rumors["lines"], ["Rumor A.", "You asked 0 times."])
	assert_eq(JSON.stringify(player.sites), before, "nothing counted")
	assert_false(_button(rumors, "_leave").is_empty())
	rumors = inn().do_effects(player, "inn", "paid_talk")
	assert_eq(player.gold, 95, "a talk with a price pays it")
	assert_eq(rumors["lines"], ["Rumor B.", "You asked 1 times."], "one_of by uses: the next in turn; {count}: the line's counter")
	rumors = inn().do_effects(player, "inn", "paid_talk")
	rumors = inn().do_effects(player, "inn", "paid_talk")
	assert_eq(String(rumors["lines"][0]), "Rumor A.", "and around again")
	assert_eq(_button(inn().describe(player, "inn"), ":inn:paid_talk"), [], "its ladder is used up")


func test_one_of_by_day_turns_with_the_days() -> void:
	var content := INN.sites()
	content["sites"]["inn"]["panes"][0]["lines"][0].erase("by")
	INN.install(ROOT, content)
	AdventurePlugins.scan()
	var player := hero()
	var seen: Array = []
	for day in 4:
		player.journey_time = WorldStatus.DAY * day
		seen.append(String(inn().do_effects(player, "inn", "ask")["lines"][0]))
	assert_eq(seen, ["Rumor A.", "Rumor B.", "Rumor C.", "Rumor A."])


# ------------------------------------------------------------------ roll --

func test_a_roll_is_on_the_plugins_own_dice_and_the_same_after_a_reload() -> void:
	var plain := hero([])
	var player := hero()
	player.gold = 1000
	var dice := player.dice
	var state := player.world.rand_state
	var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	var outcomes: Array = []
	for i in 12:
		var gold := player.gold
		var pane := inn().do_effects(player, "inn", "gamble")
		outcomes.append(String(pane["lines"][0]))
		assert_eq(player.gold - gold, 20 if outcomes[-1] == "You win." else -10, "the price, and the outcome's effects alone")
	assert_true("You win." in outcomes and "You lose." in outcomes, "both outcomes come up in twelve rolls: %s" % str(outcomes))
	assert_eq(player.dice, dice, "the adventure's dice are not cast")
	assert_eq(player.world.rand_state, state)
	assert_eq(player.world.fingerprint(), plain.world.fingerprint(), "the 1997 world is the same with the plugin and its rolls")
	assert_eq(plain.dice, dice, "and the dice the same as a campaign's without it")
	var again := AdventurePlayer.from_dict(saved)
	AdventureExpansions.initialize(again)
	var replay: Array = []
	for i in 12:
		replay.append(String(inn().do_effects(again, "inn", "gamble")["lines"][0]))
	assert_eq(replay, outcomes, "the save reloaded rolls the same: nothing to gain by it")
	assert_eq(_button(inn().describe(again, "inn", "games"), ":inn:gamble"), [], "and the ladder ends")


# ------------------------------------------------------------------ duels --

func test_a_duel_takes_its_stake_first_and_pays_the_win_once() -> void:
	var player := hero()
	_hold(player, ["Forest", "Forest", "Grizzly Bears"])
	player.gold = 250
	var games := inn().describe(player, "inn", "games")
	assert_eq(String(_button(games, ":inn:duel")[1]), "Duel The Champion")
	var record := player.duel_record()
	assert_eq(inn().duel_begin(player, "inn", "duel"), 100)
	assert_eq(player.gold, 150, "the stake is paid as the duel begins")
	assert_eq(inn().uses(player, "inn", "duel"), 0, "count win: a press is not a use")
	var lost := inn().duel_end(player, "inn", "duel", false, 100)
	assert_eq(lost["lines"], ["The Champion has defeated you."], "the engine's sentence for a branch without lines")
	assert_eq(player.gold, 150)
	assert_eq(inn().duel_begin(player, "inn", "duel"), 100, "a loss: the same price again")
	var won := inn().duel_end(player, "inn", "duel", true, 100)
	assert_eq(player.gold, 350, "50 left, and 300 won")
	assert_eq(won["lines"], ["Well fought; 1 wins."])
	assert_eq(inn().counter(player, "wins"), 1)
	assert_eq(inn().uses(player, "inn", "duel"), 1)
	assert_eq(inn().duel_begin(player, "inn", "duel"), -1, "the ladder is used up: no second prize")
	assert_eq(player.gold, 350)
	assert_eq(player.duel_record(), record, "not the hero's own duel record")
	var events := player.journal.filter(func(row: Dictionary) -> bool: return String(row.get("event", "")) == "inn:duel")
	assert_eq(events.map(func(row: Dictionary) -> String: return String(row["text"])), ["Lost to The Champion.", "Defeated The Champion."])


func test_a_duel_is_refused_without_a_deck_or_the_stake() -> void:
	var player := hero()
	_hold(player, ["Forest"])
	player.gold = 50
	assert_string_contains(inn().refusal(player, "inn", inn().action_of("inn", "duel")), "You need 100 gold")
	player.gold = 500
	assert_eq(inn().refusal(player, "inn", inn().action_of("inn", "duel")), "")
	player.cards[0]["decks"] = []
	assert_eq(inn().refusal(player, "inn", inn().action_of("inn", "duel")), PluginText.DEFAULTS["deck.empty"])
	assert_eq(inn().duel_begin(player, "inn", "duel"), -1)
	assert_eq(player.gold, 500, "nothing paid")
	player.cards[0] = {"card": "No Such Card Anywhere", "decks": [0]}
	assert_eq(inn().refusal(player, "inn", inn().action_of("inn", "duel")), PluginText.DEFAULTS["deck.unknown"])


func test_the_duels_foe_is_the_plugins_own() -> void:
	var player := hero()
	_hold(player, ["Forest", "Forest", "Grizzly Bears"])
	var foe := inn().foe("champion")
	var config: DuelConfig = load("res://game/adventure/plugins/plugin_journey.gd").foe_config(player, foe, "The Inn")
	assert_eq(config.lives[1], 12, "never scaled to the hero")
	assert_eq(config.decks[1].size(), 20)
	assert_eq(config.player_names[1], "The Champion")
	assert_eq(config.deck_names[1], "The Inn")


# ----------------------------------------------------------------- trades --

func test_a_card_is_never_sold_under_nor_bought_over_what_a_town_pays() -> void:
	var player := hero()
	_hold(player, ["Forest", "Forest"])
	player.gold = 1000
	var buy := inn().action_of("inn", "buy")
	var sell := inn().action_of("inn", "sell")
	var floor_price := CardShop.sell_range("Grizzly Bears").y
	assert_gt(floor_price, 1, "control: a town pays more than the plugin asks")
	var offered := inn().buyable(player, "inn", buy)
	assert_eq(int(offered["Grizzly Bears"]), floor_price, "1 gold asked: the town's price is the floor")
	assert_eq(int(offered["Black Lotus"]), maxi(5000, CardShop.sell_range("Black Lotus").y))
	var pane := inn().buy_card(player, "inn", "buy", "Grizzly Bears")
	assert_eq(player.gold, 1000 - floor_price)
	assert_eq(DataSites.held(player, "Grizzly Bears"), 1)
	assert_string_contains(String(pane["lines"][0]), "Grizzly Bears is yours for %d gold." % floor_price)
	assert_false(inn().buyable(player, "inn", buy).has("Grizzly Bears"), "stock 1: sold out")
	inn().buy_card(player, "inn", "buy", "Grizzly Bears")
	assert_eq(DataSites.held(player, "Grizzly Bears"), 1)
	pane = inn().buy_card(player, "inn", "buy", "Black Lotus")
	assert_string_contains(String(pane["lines"][0]), "You need")
	assert_eq(DataSites.held(player, "Black Lotus"), 0, "not without the gold")
	var cap := CardShop.sell_range("Forest").y
	var gold := player.gold
	assert_eq(int(inn().sellable(player, "inn", sell)["Forest"]), cap, "100000 offered: the town's price is the cap")
	inn().sell_card(player, "inn", "sell", "Forest")
	assert_eq(player.gold, gold + cap)
	assert_eq(DataSites.held(player, "Forest"), 1)
	inn().sell_card(player, "inn", "sell", "Grizzly Bears")
	assert_eq(DataSites.held(player, "Grizzly Bears"), 1, "only what the place asks for")
	inn().sell_card(player, "inn", "sell", "Forest")
	assert_eq(inn().refusal(player, "inn", sell), PluginText.DEFAULTS["site.nothing_to_sell"])
	var read := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_false(inn().buyable(read, "inn", buy).has("Grizzly Bears"), "the stock is kept by the save")


# ------------------------------------------------------------------ tasks --

func test_a_task_is_a_row_and_a_map_target_until_it_is_done() -> void:
	var player := hero()
	player.gold = 500
	var point: Array = player.world.expansion[AdventureSites.KEY]["inn:inn"]
	var at := Vector2i(int(point[0]), int(point[1]))
	var rows := AdventureTasks.rows(player).filter(func(row: Dictionary) -> bool: return String(row["id"]).begins_with("mainland/site:inn:"))
	assert_eq(rows.size(), 1, "the cellar's task waits for its dungeon")
	assert_eq([rows[0]["id"], rows[0]["title"], rows[0]["text"], rows[0]["tile"]], ["mainland/site:inn:go_inn", "Visit the inn", "Ask for rumors at the inn.", at])
	assert_true(WorldStatus.targets(player).any(func(target: Dictionary) -> bool: return target["tile"] == at and target["name"] == "Visit the inn" and target["kind"] == "quest"))
	inn().do_effects(player, "inn", "paid_talk")
	inn().do_effects(player, "inn", "cellar")
	rows = AdventureTasks.rows(player).filter(func(row: Dictionary) -> bool: return String(row["id"]).begins_with("mainland/site:inn:"))
	assert_eq(rows.size(), 2, "the rows are read again when the plugin's progress changes")
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) > String(b["id"]))
	assert_eq([rows[0]["status"], rows[0]["text"]], ["completed", "You heard the rumors."])
	assert_eq(String(rows[1]["title"]), "Find The Cellar.")
	var slot: Dictionary = player.world.encounters[inn().dungeon_index(player, "cellar")]
	assert_eq(rows[1]["tile"], Vector2i(int(slot["x"]), int(slot["y"])))
	var targets := WorldStatus.targets(player)
	assert_false(targets.any(func(target: Dictionary) -> bool: return target["tile"] == at), "a task done guides nowhere")
	assert_true(targets.any(func(target: Dictionary) -> bool: return target["tile"] == rows[1]["tile"]))
	assert_eq(AdventureSites.task_rows(hero([])), [] as Array[Dictionary], "a campaign without the plugin has none")
	assert_eq(AdventureSites.targets(hero([])), [] as Array[Dictionary])


# ------------------------------------------------------------------ saves --

func test_the_counters_are_saved_in_format_9_and_an_empty_record_is_as_before() -> void:
	var player := hero()
	player.gold = 100
	inn().do_effects(player, "inn", "ask")
	assert_false(player.sites.has("inn"), "nothing written by a plain talk")
	inn().do_effects(player, "inn", "paid_talk")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	assert_eq(int(saved["version"]), 9)
	assert_eq(saved["sites"]["inn"]["counters"], {"visits": 1.0})
	var read := AdventurePlayer.from_dict(saved)
	assert_eq(read.sites, player.sites)
	assert_eq(inn().counter(read, "visits"), 1)
	# A record without counters (API 2's, or an older game's) reads as it did.
	assert_eq(AdventurePlayer._cleaned_sites({"old_hut": {"uses": {"hut.secret": 1}, "flags": [], "dungeons": {}}}),
		{"old_hut": {"uses": {"hut.secret": 1}, "flags": [], "dungeons": {}}})
	assert_eq(AdventurePlayer._cleaned_sites({"inn": {"counters": {"wins": 5000, "bad": "x", 7: 1}}})["inn"]["counters"], {"wins": 1000},
		"a damaged save's counters are cleaned, not believed")
