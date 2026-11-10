extends GutTest
## AN UPDATED PLUGIN NEVER COSTS A SAVE (adventure plugins, 2026-11-10; the
## lead's rule on the guide writer's finding): a land whose saved map or
## progress the INSTALLED version cannot read — a town moved, a quest taken
## out — is held exactly as a missing plugin's land is. The save opens; the
## land's map and progress are carried as they were saved; its ships do not
## sail and the mainland says why; a hero standing on it finds the game's
## own Ship home; putting the old version back brings the land back.
## Structural damage (not a version's) is still refused.
## The versions are copies of the Last Refuge prototype under the test
## profile: 1.0.0 as shipped, 1.1.0 changed by each test.

const ZIPS := preload("res://tests/support/plugin_zips.gd")
const PROTOTYPE := "res://expanded_adventure/Fallen_Empires_Refuge_prototype"
const ROOT := "user://plugin_updates_tests"

var _pack_before: bool


func before_each() -> void:
	_pack_before = CardPacks.is_enabled(FallenEmpiresPack.ID)
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)


func after_each() -> void:
	ZIPS.remove(ROOT)
	AdventurePlugins.folders_override = [] as Array[String]
	AdventurePlugins.scan()
	CardPacks.set_enabled(FallenEmpiresPack.ID, _pack_before)


## The prototype installed alone, as [param version], each of [param edits]
## `{rel: Callable(Dictionary)}` changing its JSON file.
func _install(version: String, edits := {}) -> void:
	ZIPS.remove(ROOT)
	var at := ROOT.path_join("Refuge_" + version.replace(".", "_"))
	for rel in ZIPS.files_of(PROTOTYPE):
		DirAccess.make_dir_recursive_absolute(at.path_join(rel).get_base_dir())
		var file := FileAccess.open(at.path_join(rel), FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(PROTOTYPE.path_join(rel)))
		file.close()
	edits["plugin.json"] = func(manifest: Dictionary) -> void: manifest["version"] = version
	for rel: String in edits:
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(at.path_join(rel)))
		(edits[rel] as Callable).call(parsed)
		var file := FileAccess.open(at.path_join(rel), FileAccess.WRITE)
		file.store_string(JSON.stringify(parsed, "\t"))
		file.close()
	AdventurePlugins.folders_override = [ROOT] as Array[String]
	AdventurePlugins.scan()
	assert_true(AdventurePlugins.valid("refuge"), "%s installs: %s" % [version, AdventurePlugins.refusal("refuge")])
	assert_eq(String(AdventurePlugins.row("refuge").get("version", "")), version)


## 1.1.0 with Havenwood moved from town slot 5 to slot 6.
func _town_moved() -> void:
	_install("1.1.0", {
		"world.json": func(world: Dictionary) -> void:
			for town: Dictionary in world["towns"]["list"]:
				if int(town["slot"]) == 5: town["slot"] = 6
			world["objectives"]["channel"]["exclude"] = [1, 2, 3, 4, 6],
		"quests.json": func(quests: Dictionary) -> void:
			for quest: Dictionary in quests["quests"]:
				if int(quest["giver"]) == 5: quest["giver"] = 6
			quests["errands_off"] = [0, 1, 2, 3, 4, 6],
	})


## 1.1.0 with the last quest, Room to Grow, taken out.
func _quest_removed() -> void:
	_install("1.1.0", {"quests.json": func(quests: Dictionary) -> void: (quests["quests"] as Array).pop_back()})


func _hero() -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.adventures = ["refuge"]
	setup.packs = ["pack-2"]
	setup.seed_text = "48271"
	setup.player_name = "Wayfarer"
	var record := setup.resolve({"pack-2": "1"})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(hero)
	return hero


func _refuge() -> DataRegion:
	return AdventureExpansions.provider("refuge") as DataRegion


func _saved(hero: AdventurePlayer) -> Dictionary:
	return JSON.parse_string(JSON.stringify(hero.to_dict()))


## A 1.0.0 hero who visited the island (and, with [param finished], won its
## last pledge there), saved on the mainland or, [param on_island], there.
func _v1_save(on_island: bool, finished := false) -> Dictionary:
	_install("1.0.0")
	var hero := _hero()
	assert_true(_refuge().travel(hero), "to the island")
	if finished:
		assert_true(_refuge().finish_quest(hero, 4), "the last pledge won")
	if not on_island:
		assert_true(_refuge().travel(hero), "and home")
	return _saved(hero)


func _assert_held(loaded: AdventurePlayer, saved: Dictionary, why: String) -> void:
	assert_not_null(loaded, why + ": the save opens")
	if loaded == null: return
	assert_true(AdventureExpansions.held(loaded, "refuge"), why + ": the land is held")
	assert_false(AdventureExpansions.enabled_for(loaded, "refuge"), why + ": its ships do not sail")
	assert_true(AdventureExpansions.ticked(loaded, "refuge"), why + ": still the campaign's")
	var again := _saved(loaded)
	assert_eq(JSON.stringify(again["expansions"]["refuge"]), JSON.stringify(saved["expansions"]["refuge"]),
		why + ": its progress carried as it was saved")
	if saved["regions"].has("refuge"):
		assert_eq(JSON.stringify(again["regions"]["refuge"]), JSON.stringify(saved["regions"]["refuge"]),
			why + ": its map carried as it was saved")


func test_a_town_moved_by_an_update_holds_the_land_and_the_save_opens() -> void:
	var saved := _v1_save(false)
	_town_moved()
	var loaded := AdventurePlayer.from_dict(saved)
	_assert_held(loaded, saved, "a town moved")
	if loaded == null: return
	assert_true(AdventureExpansions.places(loaded.world).is_empty(), "no anchorage")
	assert_false(_refuge().travel(loaded), "no voyage")
	assert_eq(AdventureExpansions.mainland_note(loaded),
		"Ships to The Last Refuge do not sail: this adventure was saved with version 1.0.0 of the plugin "
		+ "The Last Refuge (Fallen Empires prototype), and the installed version 1.1.0 cannot read it.")
	assert_false(AdventureTasks.rows(loaded).any(func(task: Dictionary) -> bool:
		return String(task["id"]).begins_with("refuge/") or String(task["id"]).contains("voyage:refuge")),
		"no task of a land it cannot read")


func test_a_hero_on_the_island_when_a_town_moved_sails_home() -> void:
	var saved := _v1_save(true)
	_town_moved()
	var loaded := AdventurePlayer.from_dict(saved)
	_assert_held(loaded, saved, "on the island, a town moved")
	if loaded == null: return
	assert_eq(AdventureRegions.id(loaded.world), "refuge")
	var point: Array = loaded.world.expansion["port"]
	var pane := AdventureExpansions.describe(loaded, Vector2i(int(point[0]), int(point[1])))
	assert_eq(pane.get("kind"), "region_port")
	assert_eq(pane.get("actions", [[]])[0], [AdventureExpansions.HOME_ACTION, "Sail to Shandalar", true], "Ship home")
	assert_string_contains(" ".join(pane.get("lines", [])), "1.0.0")
	assert_eq(AdventureExpansions.status_lines(loaded), [] as Array[String], "the installed version's words are not said")
	var here := AdventureTasks.rows(loaded).filter(func(task: Dictionary) -> bool: return task["region"] == "refuge")
	assert_eq(here.map(func(task: Dictionary) -> String: return task["id"]), ["refuge/return"])
	assert_true(AdventureExpansions.voyage(loaded, AdventureRegions.MAINLAND), "home")
	assert_true(AdventureExpansions.held(loaded, "refuge"), "still held at home")
	assert_true(AdventureExpansions.places(loaded.world).is_empty())


func test_a_quest_removed_by_an_update_holds_the_land() -> void:
	var saved := _v1_save(false, true)
	_quest_removed()
	_assert_held(AdventurePlayer.from_dict(saved), saved, "a quest removed")
	var island := _v1_save(true, true)
	_quest_removed()
	var loaded := AdventurePlayer.from_dict(island)
	_assert_held(loaded, island, "on the island, a quest removed")
	if loaded == null: return
	var point: Array = loaded.world.expansion["port"]
	var pane := AdventureExpansions.describe(loaded, Vector2i(int(point[0]), int(point[1])))
	assert_eq(pane.get("actions", [[]])[0], [AdventureExpansions.HOME_ACTION, "Sail to Shandalar", true])


func test_a_save_the_update_can_read_is_not_held() -> void:
	_install("1.0.0")
	var hero := _hero()
	assert_true(_refuge().travel(hero))
	assert_true(_refuge().travel(hero))
	var saved := _saved(hero)
	_quest_removed()
	var loaded := AdventurePlayer.from_dict(saved)
	assert_not_null(loaded)
	if loaded == null: return
	assert_false(AdventureExpansions.held(loaded, "refuge"), "nothing done there the update cannot read")
	assert_true(AdventureExpansions.enabled_for(loaded, "refuge"))
	assert_eq(String(loaded.adventures[0]["version"]), "1.1.0", "the version that read it last")


func test_putting_the_old_version_back_brings_the_land_back() -> void:
	var saved := _v1_save(false)
	_town_moved()
	var held := AdventurePlayer.from_dict(saved)
	assert_not_null(held)
	var kept := _saved(held)
	_install("1.0.0")
	var loaded := AdventurePlayer.from_dict(kept)
	assert_not_null(loaded)
	if loaded == null: return
	assert_false(AdventureExpansions.held(loaded, "refuge"))
	assert_true(AdventureExpansions.enabled_for(loaded, "refuge"))
	assert_eq(AdventureExpansions.mainland_note(loaded), "")
	assert_true(_refuge().travel(loaded), "the ship sails again")
	assert_eq(loaded.world.fingerprint(), AdventurePlayer._world_from(saved["regions"]["refuge"]["world"], Vector2i.ZERO).fingerprint(),
		"to the island as it was saved")


func test_structural_damage_is_still_refused() -> void:
	var saved := _v1_save(false, true)
	_town_moved()
	var grid := saved.duplicate(true)
	grid["regions"]["refuge"]["world"]["grid"] = ["00"]
	assert_null(AdventurePlayer.from_dict(grid), "a land's map that is no map")
	var nameless := saved.duplicate(true)
	nameless["regions"]["refuge"]["world"]["expansion"]["region"] = "elsewhere"
	assert_null(AdventurePlayer.from_dict(nameless), "a map that names another land")
	var placeless := saved.duplicate(true)
	placeless["regions"]["refuge"]["world"]["sites"] = []
	assert_null(AdventurePlayer.from_dict(placeless), "a land's map without its 128 places")
	var portless := saved.duplicate(true)
	(portless["regions"]["refuge"]["world"]["expansion"] as Dictionary).erase("port")
	assert_null(AdventurePlayer.from_dict(portless), "a land with no way home")
	for broken: Dictionary in [{"quests": "five"}, {"quests": [0, 0]}, {"quests": [-1]}, {"pending": [""]},
			{"stages": {"x": 1}}, {"liberated": "yes"}]:
		var damaged := saved.duplicate(true)
		damaged["expansions"]["refuge"].merge(broken, true)
		assert_null(AdventurePlayer.from_dict(damaged), "garbage under any version: %s" % [broken])
	assert_not_null(AdventurePlayer.from_dict(saved), "the undamaged save opens")
