extends GutTest
## 0.70.11 campaign, smooth2 #4: the first voyage to an island makes its
## world on a worker while the harbor says "Setting sail..."; the island is
## the one made in place, to the bit; Escape meanwhile stays ashore and
## keeps the island for the next Sail.

const SAVES := "user://c1126_adv_first_sail_saves"

var screen: WorldScreen


func before_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.adventures = ["refuge"]
	setup.packs = ["pack-2"]
	setup.seed_text = "12345"
	setup.player_name = "Wayfarer"
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({"pack-2": "1"})
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.set_process(false)
	screen.player.monsters = [] as Array


func after_each() -> void:
	PluginJourney.sail_aside_forced = -1
	AdventureExpansions._made_ahead = {}
	AdventurePlayer.finish_saves()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file in dir.get_files():
			dir.remove(file)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)


func _refuge() -> DataRegion:
	return AdventureExpansions.provider("refuge") as DataRegion


func _to_port() -> Vector2i:
	var port := Vector2i(-1, -1)
	for place in AdventureExpansions.places(screen.player.world):
		if String(place["kind"]) == "port":
			port = Vector2i(int(place["point"][0]), int(place["point"][1]))
	screen.player.position = port * 32 + Vector2i(16, 16)
	screen.show_player(screen.player)
	screen.visit(port)
	return port


func _choose(action: String) -> void:
	screen._visit.choose(action)
	await get_tree().process_frame
	await get_tree().process_frame


func _wait_for_sail() -> void:
	for n in 600:
		await get_tree().process_frame
		if _refuge().on_island(screen.player):
			return


func test_headless_the_island_is_made_in_place_as_ever() -> void:
	assert_false(PluginJourney.sails_aside(), "no worker under the tests by the rule")
	_to_port()
	await _choose("refuge_sail")
	assert_true(_refuge().on_island(screen.player), "there in the same call")


func test_the_first_voyage_waits_under_setting_sail_and_lands_on_the_same_island() -> void:
	PluginJourney.sail_aside_forced = 1
	var hero := screen.player
	var beside := AdventureExpansions.generate("refuge", hero.world.seed, hero.world.color, hero.difficulty)
	_to_port()
	await _choose("refuge_sail")
	assert_false(_refuge().on_island(hero), "not yet: the island is being made")
	assert_true(screen.visiting(), "the harbor's pane holds the world")
	assert_eq(screen._visit.words(), PluginJourney.SETTING_SAIL)
	assert_eq(screen._visit._choices.get_child_count(), 0, "no button to press twice")
	await _wait_for_sail()
	assert_true(_refuge().on_island(hero), "the ship sailed")
	assert_eq(hero.made_fingerprint, beside.fingerprint(), "the island made in place, to the bit")
	assert_true(screen.visiting(), "the arrival's pane")
	assert_ne(screen._visit.words(), PluginJourney.SETTING_SAIL)
	assert_true(AdventureExpansions._made_ahead.is_empty(), "the island kept was taken")
	assert_not_null(AdventurePlayer.load_from(hero.save_path()), "saved on arrival")
	# Home and out again: the saved map, no waiting pane.
	await _choose("refuge_sail")
	assert_false(_refuge().on_island(hero))
	screen.visit(hero.tile(), false)
	await _choose("refuge_sail")
	assert_true(_refuge().on_island(hero), "a second voyage sails at once")


func test_escape_while_setting_sail_stays_ashore_and_keeps_the_island() -> void:
	PluginJourney.sail_aside_forced = 1
	var hero := screen.player
	var port := _to_port()
	await _choose("refuge_sail")
	assert_eq(screen._visit.words(), PluginJourney.SETTING_SAIL)
	screen._visit.left.emit("")
	for n in 600:
		await get_tree().process_frame
		if not AdventureExpansions._made_ahead.is_empty():
			break
	await get_tree().process_frame
	assert_false(_refuge().on_island(hero), "ashore")
	assert_eq(hero.tile(), port)
	assert_eq(String(AdventureExpansions._made_ahead.get("id", "")), "refuge", "the island kept")
	PluginJourney.sail_aside_forced = 0
	screen.visit(port, false)
	await _choose("refuge_sail")
	assert_true(_refuge().on_island(hero), "the next Sail leaves at once")
	assert_true(AdventureExpansions._made_ahead.is_empty())
