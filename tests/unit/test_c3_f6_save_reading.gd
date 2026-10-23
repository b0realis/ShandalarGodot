extends GutTest
## A SAVE READ FIELD BY FIELD (campaign of 2026-10-23, fixer f6, h4-5):
## [method AdventurePlayer.from_dict] takes each field only when it is of
## its kind and its default otherwise, keeps a record the world reads only
## when it is whole, holds places and indices to the world — and keeps the
## rest of the save. One wrongly typed field used to make the whole save
## unreadable; broken records loaded and then flooded the world with
## errors. A save from before the newer fields still loads as it did.
## (Any engine or script error on the way fails the run.)

var player: AdventurePlayer
var base: Dictionary


func before_all() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Probe Hero"
	setup.color = "green"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "4242"
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	player.adventure_id = "base"
	base = JSON.parse_string(JSON.stringify(player.to_dict()))


## The base save with [param change] made to a copy, read back.
func _read(change: Callable) -> AdventurePlayer:
	var data: Dictionary = base.duplicate(true)
	change.call(data)
	return AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(data)))


func _a_town(world: ShandalarWorld) -> int:
	for slot in world.sites.size():
		if int(world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			return slot
	return -1


func test_a_whole_save_reads_back_as_it_was() -> void:
	var back := _read(func(_d: Dictionary) -> void: pass)
	assert_not_null(back)
	assert_eq(back.to_dict(), player.to_dict(), "nothing changed by the reading")


func test_one_wrongly_typed_field_no_longer_refuses_the_save() -> void:
	var cases := {
		"deck_names": func(d: Dictionary) -> void: d["carried"]["deck_names"] = "abc",
		"figure_colors": func(d: Dictionary) -> void: d["hero"]["figure_colors"] = "red",
		"playmat": func(d: Dictionary) -> void: d["hero"]["playmat"] = [1],
		"world_magics": func(d: Dictionary) -> void: d["carried"]["world_magics"] = null,
		"town_quests": func(d: Dictionary) -> void: d["record"]["town_quests"] = [],
		"journal": func(d: Dictionary) -> void: d["record"]["journal"] = {"a": 1},
		"quest": func(d: Dictionary) -> void: d["record"]["quest"] = "go",
		"amulets": func(d: Dictionary) -> void: d["carried"]["amulets"] = [1, 2],
		"shops": func(d: Dictionary) -> void: d["world"]["shops"] = [],
		"sites": func(d: Dictionary) -> void: d["world"]["sites"] = [{"x": "a"}, 5],
		"encounters": func(d: Dictionary) -> void: d["world"]["encounters"] = [1, 2],
		"start": func(d: Dictionary) -> void: d["world"]["start"] = [5],
		"gold": func(d: Dictionary) -> void: d["carried"]["gold"] = "lots",
		"where": func(d: Dictionary) -> void: d["where"] = "here",
	}
	for field in cases:
		var back := _read(cases[field])
		assert_not_null(back, field + ": the save still loads")
		if back != null:
			assert_eq(back.name, "Probe Hero", field + ": and the rest of it is kept")
			assert_eq(back.world.fingerprint(), player.world.fingerprint(), field + ": the world too")
	assert_eq(_read(cases["deck_names"]).deck_names, ["", "", ""] as Array[String], "the default")
	assert_eq(_read(cases["gold"]).gold, 0)
	assert_eq(_read(cases["amulets"]).amulet_count(), 0)
	assert_eq(_read(cases["journal"]).journal, [])
	assert_eq(_read(cases["quest"]).quest, {})
	assert_eq(_read(cases["where"]).position, player.world.start, "a hero with no place stands at the start")


func test_a_save_whose_world_is_broken_is_still_refused_quietly() -> void:
	assert_null(_read(func(d: Dictionary) -> void: d["world"]["grid"][3] = "zz"), "a grid row that is not hex")
	assert_null(_read(func(d: Dictionary) -> void: d["world"]["grid"][3] = 5))
	assert_null(_read(func(d: Dictionary) -> void: d["world"]["grid"] = "x"))
	assert_null(_read(func(d: Dictionary) -> void: d["hero"] = "Bob"), "a main part that is not a record")
	assert_null(_read(func(d: Dictionary) -> void: d["version"] = 2), "a newer save")


func test_broken_records_are_dropped_and_the_rest_kept() -> void:
	var back := _read(func(d: Dictionary) -> void:
		d["world"]["monsters"] = [5, "x", {"slot": 0, "kind": "lair", "color": 1},
			{"slot": 1, "kind": "lair", "x": 64, "y": 96, "color": 2},
			{"slot": 1, "kind": "lair", "x": 32, "y": 32, "color": 3},
			{"slot": 2, "kind": "lair", "x": -40, "y": 99999, "color": 3},
			{"slot": 7, "kind": "creature", "town": 999, "x": 10, "y": 10}]
		d["carried"]["cards"] = ["Lightning Bolt", 5, {"card": 3}, {"decks": "x"},
			{"card": "Nope Card", "decks": [0, 9, "a", 0]}, {"card": "Giant Growth", "decks": [1]}])
	assert_eq(back.monsters.size(), 1, "only the whole creature, once to its slot, in the world")
	assert_eq([int(back.monsters[0]["slot"]), int(back.monsters[0]["x"]), int(back.monsters[0]["y"])], [1, 64, 96])
	assert_eq(back.cards.size(), 2, "the cards with names")
	assert_eq(back.cards[0], {"card": "Nope Card", "decks": [0]}, "a card not in the packs is still the hero's")
	assert_eq(back.cards[1], {"card": "Giant Growth", "decks": [1]})


func test_places_and_indices_are_held_to_the_world() -> void:
	var town := _a_town(player.world)
	var back := _read(func(d: Dictionary) -> void:
		d["where"]["x"] = -99999
		d["where"]["y"] = 99999999
		d["where"]["facing"] = 40
		d["world"]["world_magic_sites"] = [999, -1, town]
		d["record"]["last_town"] = 4000
		d["hero"]["difficulty"] = 9
		d["hero"]["color"] = "purple"
		d["carried"]["current_deck"] = 7
		d["carried"]["gold"] = 1e300
		d["carried"]["food"] = -3
		d["clocks"]["quest_timer"] = 1e20
		d["world"]["encounters"][0]["cards"] = [0, 999, -2, "x"])
	var edge := ShandalarWorld.TILES * 32 - 1
	assert_eq(back.position, Vector2i(0, edge), "on the map")
	assert_eq(back.facing, 8)
	assert_eq(back.world.world_magic_sites.slice(0, 3), [0, 0, town] as Array[int], "a site of the world or none")
	assert_eq(back.last_town, -1)
	assert_eq([back.difficulty, back.color, back.current_deck], [3, "white", 2])
	assert_eq(back.gold, AdventurePlayer.MOST)
	assert_eq(back.food, 0)
	assert_eq(back.quest_timer, AdventurePlayer.MOST)
	assert_eq(back.world.encounters[0]["cards"], [0] as Array[int], "a dungeon's cards from the table")


func test_misshapen_shops_and_journal_lines_are_mended() -> void:
	var town := _a_town(player.world)
	var back := _read(func(d: Dictionary) -> void:
		d["world"]["shops"] = {str(town): {"cards": ["Shatter", 5, ""], "restock": "r", "hint": "x", "traded": "y"},
			"abc": {"cards": []}, "9999": {"cards": []}, str((town + 1) % 128): "abc",
			str((town + 2) % 128): []}
		d["record"]["journal"] = [5, "x", {"event": 3}, {"event": "duel", "won": "yes", "x": "a"},
			{"event": "visit", "text": "Visited Kraag", "x": 3, "y": 4, "time": 77, "day": 2}]
		d["record"]["town_quests"] = {"3": 40, "4": "soon"}
		d["record"]["defeated_wizards"] = ["red", 5, "purple", "red"]
		d["duels"]["victories"] = ["x", 5, {"color": "purple"}])
	assert_eq(back.shops.keys(), [str(town)], "only a town's own shop")
	var shop: Dictionary = back.shops[str(town)]
	assert_eq(shop["cards"], ["Shatter", "", ""])
	assert_eq(shop["restock"], [CardShop.NEVER_FILLED, CardShop.NEVER_FILLED, CardShop.NEVER_FILLED],
		"a place for each card, never filled")
	assert_false(shop.has("hint") or shop.has("traded"), "the misshapen parts gone")
	assert_eq(back.journal.size(), 3, "the lines that are lines")
	assert_eq(back.journal[0], {"event": ""})
	assert_eq(back.journal[1], {"event": "duel", "won": false, "x": 0})
	assert_eq(back.duel_record(), {"won": 0, "lost": 1})
	assert_eq(back.town_quests, {"3": 40})
	assert_eq(back.defeated_wizards, ["red"] as Array[String])
	assert_eq(back.duel_victories, [{"color": "purple"}])
	CardShop.offers(back, town)
	assert_eq(HeroStats.record(back)["lost"], 1, "the record reads the mended lines")


func test_a_save_from_before_the_newer_fields_loads_as_it_did() -> void:
	var back := _read(func(d: Dictionary) -> void:
		for key in ["town_quests", "wise_man", "quest_offer", "last_town"]:
			d["record"].erase(key)
		for key in ["shops", "monsters", "lair_respawn", "world_magic_sites"]:
			d["world"].erase(key)
		for key in ["deck_names", "deck_notes", "deck_colors"]:
			d["carried"].erase(key)
		d["hero"].erase("figure_colors")
		d["hero"].erase("packs")
		d["adventure"].erase("slot_name")
		d["clocks"].erase("quickening"))
	assert_not_null(back)
	assert_eq([back.name, back.gold, back.position], [player.name, player.gold, player.position])
	assert_eq(back.last_town, -1)
	assert_eq([back.shops, back.monsters, back.town_quests], [{}, [], {}])


## The bug pass after the campaign (r3-4): a quest, the quest offered, the
## wise man's word and the duels won are read by kind too — a hand-edited
## or future save with a word where a number goes made errors on every
## tick of the clock.
func test_the_quest_the_wise_man_and_the_victories_are_read_by_kind() -> void:
	var town := _a_town(player.world)
	var fine := {"type": 0, "destination": town, "giver": town, "color": 2, "data": 1, "deadline": 900}
	var back := _read(func(d: Dictionary) -> void:
		d["record"]["quest"] = fine
		d["record"]["quest_offer"] = {"type": 0, "destination": town, "color": "red", "at": town}
		d["record"]["wise_man"] = {"stage": 2, "tale": [1], "news": "The roads are safe.", "remind": "yes"}
		d["duels"]["victories"] = [{"color": 2}, {"color": "red"}, {"color": null}, {"color": [1]}, 7])
	assert_eq(back.quest, fine, "a quest of numbers is kept whole")
	assert_eq(back.quest_offer, {}, "an offer with a word for a colour is dropped")
	assert_eq(back.wise_man, {"stage": 2, "news": "The roads are safe."}, "each part of the word by its kind")
	assert_eq(back.duel_victories, [{"color": 2}, {"color": "red"}], "the victories with a colour")
	back = _read(func(d: Dictionary) -> void:
		d["record"]["quest"] = {"type": 0, "destination": town, "giver": null, "color": 2, "data": 1, "deadline": 900})
	assert_eq(back.quest, {}, "a quest with a field of no number is dropped")
