extends GutTest
## THE STUDY PLACES, IN THE GAME (the places campaign of 2026-11-22): the
## four sites plugins written with `tools/adventure_plugin.py`'s own
## commands — a gambler's den, a riddle stone, a collector's camp, a
## duelist's ring — are read by the game's loader as they lie in
## `expanded_adventure/`, stand on a new campaign's mainland, and play: the
## den rolls, the stone talks, the collector takes a card, the ring duels.
## What the tool's `walk` says of them (tools/test_c1122_places_tool.py) is
## what happens here.

const STUDIES := {"Gamblers_Den": "gamblers_den", "Riddle_Stone": "riddle_stone",
	"Wandering_Collector": "wandering_collector", "Duelists_Ring": "duelists_ring"}
const FROM := "res://expanded_adventure"
const ROOT := "user://c1122_ptool_tests"


static func copy(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	var dir := DirAccess.open(from)
	for name in dir.get_files():
		var file := FileAccess.open(to.path_join(name), FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(from.path_join(name)))
		file.close()
	for name in dir.get_directories():
		copy(from.path_join(name), to.path_join(name))


static func remove(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for name in dir.get_directories():
		remove(path.path_join(name))
	for name in dir.get_files():
		dir.remove(name)
	DirAccess.remove_absolute(path)


func before_all() -> void:
	remove(ROOT)
	for folder: String in STUDIES:
		copy(FROM.path_join(folder), ROOT.path_join(folder))
	AdventurePlugins.folders_override = [ROOT] as Array[String]
	AdventurePlugins.scan()


func after_all() -> void:
	AdventureExpansions.clear_development()
	remove(ROOT)
	AdventurePlugins.folders_override = [] as Array[String]
	AdventurePlugins.scan()


func hero(id: String) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	setup.adventures = [id] as Array[String]
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(player)
	return player


func labels(pane: Dictionary) -> Array:
	return (pane["actions"] as Array).map(func(row: Array) -> String: return String(row[1]))


func test_the_loader_takes_each_study_plugin_as_it_lies() -> void:
	for folder: String in STUDIES:
		var id: String = STUDIES[folder]
		var rows := AdventurePlugins.all().filter(func(row: Dictionary) -> bool: return String(row["id"]) == id)
		assert_eq(rows.size(), 1, folder + " is found")
		if rows.size() == 1:
			assert_eq(rows[0]["problems"], [] as Array[String], folder)
		assert_true(AdventureSites.known(id), "%s is a sites plugin the game knows" % folder)
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FROM.path_join(folder).path_join("plugin.json")))
		assert_eq(int(manifest["api_version"]), 3, folder + " uses words of API 3")
		assert_false(AdventureSites.provider(id).file().is_empty(), folder + " has its places")


func test_each_place_stands_on_the_mainland_and_shows_its_pane() -> void:
	for folder: String in STUDIES:
		var id: String = STUDIES[folder]
		var player := hero(id)
		assert_true(AdventureSites.on(player, id), folder)
		var mine := AdventureSites.places(player.world).filter(func(place: Dictionary) -> bool: return String(place["id"]) == id)
		assert_eq(mine.size(), 1, folder + " stands once on the mainland")
		var site: String = (AdventureSites.provider(id).file()["sites"] as Dictionary).keys()[0]
		var pane := AdventureSites.provider(id).describe(player, site)
		assert_gt((pane["lines"] as Array).size(), 0, folder)
		assert_true("Leave" in labels(pane), folder + " has its way out")
		for line: String in pane["lines"]:
			assert_false("{" in line, "%s: every placeholder is filled: %s" % [folder, line])


func test_the_den_rolls_five_times_and_counts() -> void:
	var player := hero("gamblers_den")
	var den := AdventureSites.provider("gamblers_den")
	player.gold = 1000
	var seen := {}
	for n in 5:
		var before := player.gold
		var pane := den.do_effects(player, "den", "bet")
		seen[player.gold - before] = true
		assert_true(player.gold - before in [-50, 25, 100], "a throw loses 50, or pays 75 or 150")
		assert_string_contains(String(pane["lines"][0]), "You lay 50 gold on the felt.")
		assert_eq((pane["lines"] as Array).size(), 2, "the throw's line, then its outcome's")
	assert_eq(den.counter(player, "den_plays"), 5)
	assert_true(den.used_up(player, "den", den.action_of("den", "bet")))
	var spent := den.describe(player, "den")
	assert_string_contains(String(spent["lines"][1]), "The cup is packed away.")
	assert_true(labels(spent).any(func(label: String) -> bool: return label.begins_with("Sit at the high table (200 gold")),
		"the high table stays once the five throws are thrown")


func test_the_stone_talks_counts_wrong_answers_and_pays_once() -> void:
	var player := hero("riddle_stone")
	var stone := AdventureSites.provider("riddle_stone")
	var gold := player.gold
	assert_false(labels(stone.describe(player, "stone")).has("Put your ear to the stone"))
	assert_string_contains(String(stone.do_effects(player, "stone", "answer_a")["lines"][0]), "The hollow is cold")
	stone.do_effects(player, "stone", "answer_c")
	assert_eq(stone.counter(player, "stone_tries"), 2)
	var pane := stone.describe(player, "stone")
	assert_true(labels(pane).has("Put your ear to the stone"), "the hint shows after two wrong answers")
	assert_string_contains(String(pane["lines"][2]), "answered wrongly 2 times")
	assert_string_contains(String(stone.do_effects(player, "stone", "listen")["lines"][0]), "You press your ear to the rock.")
	assert_string_contains(String(stone.do_effects(player, "stone", "answer_b")["lines"][0]), "The hollow grows warm.")
	assert_eq(player.gold, gold + 100)
	assert_string_contains(String(stone.describe(player, "stone")["lines"][1]), "The words have faded")
	stone.do_effects(player, "stone", "answer_b")
	assert_eq(player.gold, gold + 100, "paid once")


func test_the_collector_takes_three_birds_and_gives_her_gift() -> void:
	var player := hero("wandering_collector")
	var camp := AdventureSites.provider("wandering_collector")
	var trade := "Hand over Ornithopter for 150 gold (3 left)"
	# A starting deck may hold the brass birds already.
	while DataSites.take_card(player, "Ornithopter"):
		pass
	assert_false(labels(camp.describe(player, "wagon")).has(trade), "no bird, no button")
	for n in 3:
		player.add_card("Ornithopter")
	assert_true(labels(camp.describe(player, "wagon")).has(trade))
	var gold := player.gold
	for n in 3:
		assert_string_contains(String(camp.do_effects(player, "wagon", "trade")["lines"][0]), "Ysolt takes Ornithopter in both hands")
	assert_eq(player.gold, gold + 450)
	assert_eq(DataSites.held(player, "Ornithopter"), 0)
	assert_eq(camp.counter(player, String(camp.file()["counters"][0])), 3)
	var blue := int(player.amulets["blue"])
	var food := player.food
	assert_true(labels(camp.describe(player, "wagon")).has("Accept her parting gift"))
	camp.do_effects(player, "wagon", "gift")
	assert_eq([int(player.amulets["blue"]), player.food], [blue + 1, food + 4])
	assert_false(labels(camp.describe(player, "wagon")).has("Accept her parting gift"), "given once")


func test_the_ring_takes_the_wager_and_opens_the_ringmasters_bout() -> void:
	var player := hero("duelists_ring")
	var ring := AdventureSites.provider("duelists_ring")
	player.gold = 1000
	assert_eq(String(ring.foe("ring_champ")["name"]), "Marda Ironhand")
	assert_true(labels(ring.describe(player, "ring")).has("Wager 50 gold against Marda Ironhand (3 left)"))
	for n in 2:
		var cost := ring.duel_begin(player, "ring", "duel")
		assert_eq(cost, 50)
		assert_string_contains(String(ring.duel_end(player, "ring", "duel", true, cost)["lines"][0]), "Marda Ironhand spits, laughs, and pays you 100 gold.")
	assert_eq(player.gold, 1100)
	assert_eq(ring.counter(player, String(ring.file()["counters"][0])), 2)
	var master := "Accept the Ringmaster's own bout (150 gold against Brannoch the Ringmaster)"
	assert_true(labels(ring.describe(player, "ring")).has(master))
	var stake := ring.duel_begin(player, "ring", "duel")
	assert_string_contains(String(ring.duel_end(player, "ring", "duel", false, stake)["lines"][0]), "Marda Ironhand pockets your wager")
	assert_true(labels(ring.describe(player, "ring")).has(master), "the Ringmaster stays when Marda's three bouts are fought")
	stake = ring.duel_begin(player, "ring", "master")
	assert_eq(stake, 150)
	ring.duel_end(player, "ring", "master", true, stake)
	assert_eq(player.gold, 1100 - 50 - 150 + 400)
	for foe: String in ["ring_champ", "ringmaster"]:
		for card: String in ring.foe(foe)["deck"]:
			assert_true(CardRegistry.has_card(card), card)
