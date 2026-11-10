extends GutTest
## A CAMPAIGN'S ADVENTURE PLUGINS IN ITS SAVE (adventure plugins, 2026-11-10;
## the spec's §0.5, §0.6 and §4): save version 8 names the ticked lands
## (`hero.adventures`); a vanilla save of any older version loads as it
## always did, while the built-in Last Refuge's own shapes, never shipped,
## are not read (the owner, 2026-11-10: *"You can break old extended
## adventure!"*); a land whose plugin is missing keeps its progress and map
## as they are, the save still opens, and a hero on its island sails home by
## the game's own pane. The lands here
## are the development fixture (tools/expansion_testing/beacon_region.gd),
## registered and taken away as a plugin is installed and removed.

const BEACON := preload("res://tools/expansion_testing/beacon_region.gd")
const ZIPS := preload("res://tests/support/plugin_zips.gd")
const EMPTY := "user://plugin_saves_tests/none"
const SCREEN := """extends Node
var player: AdventurePlayer
var _visit_tile := Vector2i.ZERO
var calls: Array = []
var opened: Array = []
func show_player(_hero: AdventurePlayer) -> void:
	calls.append("show_player")
func autosave() -> String:
	calls.append("autosave")
	return ""
func _after_leaving() -> void:
	calls.append("after_leaving")
func _sync_rest() -> void:
	calls.append("sync_rest")
func open_place(place: Dictionary) -> Control:
	opened.append(place)
	return null
"""

var _previous: Array[String] = []


func before_each() -> void:
	_previous = Settings.enabled_card_packs().duplicate()
	DirAccess.make_dir_recursive_absolute(EMPTY)
	AdventurePlugins.folders_override = [EMPTY] as Array[String]
	AdventurePlugins.scan()
	assert_true(AdventureExpansions.register_development(BEACON.ID, BEACON.descriptor()), "the fixture land")


func after_each() -> void:
	AdventureExpansions.clear_development()
	ZIPS.remove("user://plugin_saves_tests")
	AdventurePlugins.folders_override = [] as Array[String]
	AdventurePlugins.scan()
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != (id in _previous): CardPacks.set_enabled(id, id in _previous)


func hero(lands: Array[String] = [BEACON.ID], packs: Array[String] = []) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	setup.adventures = lands
	setup.packs = packs
	var versions := {}
	for id in packs: versions[id] = "1"
	var record := setup.resolve(versions)
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(player)
	return player


func _round_trip(player: AdventurePlayer) -> Dictionary:
	return JSON.parse_string(JSON.stringify(player.to_dict()))


func _screen(player: AdventurePlayer) -> Node:
	var script := GDScript.new()
	script.source_code = SCREEN
	script.reload()
	var screen: Node = script.new()
	screen.set(&"player", player)
	return autofree(screen)


func test_a_campaign_saves_its_ticked_plugins_as_version_8() -> void:
	var player := hero()
	assert_eq(player.adventures, [{"id": BEACON.ID, "version": "", "name": "Beacon Test Island", "title": "Beacon Test Island"}])
	var saved := _round_trip(player)
	assert_eq(int(saved["version"]), 8)
	assert_eq(AdventurePlayer.FORMAT_VERSION, 8)
	assert_eq(saved["hero"]["adventures"], player.adventures)
	assert_false((saved["hero"] as Dictionary).has("expanded_adventure"), "the bool of version 7 is gone")
	var loaded := AdventurePlayer.from_dict(saved)
	assert_not_null(loaded)
	assert_eq(loaded.adventures, player.adventures)
	assert_true(AdventureExpansions.chosen(loaded, BEACON.ID))
	var plain := hero([])
	assert_eq(plain.adventures, [])
	assert_false(AdventureExpansions.chosen(plain, BEACON.ID))
	assert_false((plain.world.expansion as Dictionary).has("entries"), "no anchorage for a land not ticked")
	saved["hero"]["adventures"] = [{"id": "Bad Id"}, "word", {"id": BEACON.ID, "version": 3, "name": ["x"]}, {"id": BEACON.ID}]
	assert_eq(AdventurePlayer.from_dict(saved).adventures, [{"id": BEACON.ID, "version": "", "name": "", "title": ""}],
		"a wrong row costs the row, not the save")


func test_the_embark_record_names_only_lands_this_game_knows() -> void:
	var setup := AdventureSetup.new()
	setup.adventures = [BEACON.ID, "not_installed", BEACON.ID] as Array[String]
	var record := setup.resolve({})
	assert_eq(record["adventures"], [{"id": BEACON.ID, "version": "", "name": "Beacon Test Island", "title": "Beacon Test Island"}])
	assert_false(record.has("expanded_adventure"))


func test_an_old_vanilla_save_still_loads() -> void:
	var current := _round_trip(hero([]))
	for version in range(1, AdventurePlayer.FORMAT_VERSION):
		var old := current.duplicate(true)
		old["version"] = version
		old["hero"].erase("adventures")
		for key in ["regions", "expansions", "journey", "tasks"]:
			old.erase(key)
		old["world"].erase("expansion")
		var loaded := AdventurePlayer.from_dict(old)
		assert_not_null(loaded, "a vanilla save of version %d" % version)
		if loaded == null: continue
		assert_eq(loaded.adventures, [], "no land")
		assert_eq(loaded.regions, {})
		assert_eq(loaded.expansions, {})
		assert_true(AdventureRegions.mainland(loaded))
		assert_eq(loaded.world.fingerprint(), AdventurePlayer.from_dict(current).world.fingerprint(), "the same world")
		assert_eq(int(_round_trip(loaded)["version"]), AdventurePlayer.FORMAT_VERSION, "written back as version 8")


func test_the_never_shipped_built_in_lands_shapes_are_not_read() -> void:
	var saved := _round_trip(hero([]))
	saved["version"] = 4
	saved["hero"].erase("adventures")
	saved.erase("regions")
	saved.erase("expansions")
	saved["refuge"] = {"quests": [0], "pending": [], "liberated": false, "regions": {}}
	saved["world"]["expansion"] = {"region": "mainland", "port": saved["where"]["tile"]}
	var loaded := AdventurePlayer.from_dict(saved)
	assert_not_null(loaded, "on the mainland: it loads, without its island")
	if loaded != null:
		assert_eq(loaded.adventures, [], "nothing ticked from what the old record shows")
		assert_eq(loaded.expansions, {})
		assert_false((loaded.world.expansion.get("entries", {}) as Dictionary).has("refuge"), "the old port is not an anchorage")
	var player := hero()
	assert_true(AdventureExpansions.voyage(player, BEACON.ID))
	var island := _round_trip(player)
	island["version"] = 4
	island["refuge"] = {"regions": island["regions"]}
	island.erase("regions")
	assert_null(AdventurePlayer.from_dict(island), "on an island kept in the old record: refused, never a crash")


## RV2-6: a save read and written again is the same text, on the mainland
## and on an island — a land's saved map no longer turns its whole numbers
## into decimals on the first load.
func test_a_save_is_the_same_text_after_two_cycles() -> void:
	var player := hero()
	assert_true(AdventureExpansions.voyage(player, BEACON.ID))
	for at in ["on the island", "on the mainland"]:
		var first := JSON.stringify(player.to_dict(), "\t")
		var second := JSON.stringify(AdventurePlayer.from_dict(JSON.parse_string(first)).to_dict(), "\t")
		var third := JSON.stringify(AdventurePlayer.from_dict(JSON.parse_string(second)).to_dict(), "\t")
		assert_true(second == first, at + ": saved, read and saved again, the same text")
		assert_true(third == second, at + ": and again")
		if at == "on the island":
			assert_true(AdventureExpansions.voyage(player, AdventureRegions.MAINLAND))


## RV2-7: a missing plugin's land keeps the title the campaign knew it by —
## kept in its row — in the words and the journal.
func test_a_missing_plugins_land_keeps_its_title() -> void:
	ZIPS.copy_fixture(EMPTY.path_join("tiny_isle"))
	AdventurePlugins.content_reader = ZIPS.reader
	AdventurePlugins.scan()
	var rows := AdventurePlayer.ticked_rows(["tiny_isle"])
	assert_eq(rows, [{"id": "tiny_isle", "version": "0.1.0", "name": "Tiny Isle (loader fixture)", "title": "Tiny Isle"}])
	var player := hero([])
	player.adventures = rows
	player.regions = {"tiny_isle": {}}
	ZIPS.remove(EMPTY.path_join("tiny_isle"))
	AdventurePlugins.content_reader = Callable()
	AdventurePlugins.scan()
	assert_eq(AdventureExpansions.label("tiny_isle", player), "Tiny Isle", "the land's own title, not the plugin's name")
	assert_eq(HeroStats.journal_line({"text": "Landed.", "day": 2, "region": "tiny_isle"}, player), "Day 2 · Tiny Isle: Landed.")
	assert_string_contains(AdventureExpansions.mainland_note(player), "Ships to Tiny Isle do not sail: the plugin Tiny Isle (loader fixture)")


func test_a_ticked_land_sails_and_comes_home() -> void:
	var player := hero()
	assert_true(AdventureExpansions.voyage(player, BEACON.ID))
	assert_eq(AdventureRegions.id(player.world), BEACON.ID)
	assert_false(AdventureExpansions.voyage(player, BEACON.ID), "already there")
	assert_true(AdventureExpansions.voyage(player, AdventureRegions.MAINLAND))
	assert_true(AdventureRegions.mainland(player))
	assert_false(AdventureExpansions.voyage(hero([]), BEACON.ID), "a land the campaign did not tick")


func test_a_save_whose_plugin_is_missing_opens_and_keeps_its_land() -> void:
	var player := hero()
	assert_true(AdventureExpansions.voyage(player, BEACON.ID))
	var island := player.world.fingerprint()
	player.expansions[BEACON.ID]["lit"] = 2
	assert_true(AdventureExpansions.voyage(player, AdventureRegions.MAINLAND))
	var saved := _round_trip(player)
	AdventureExpansions.clear_development()
	var loaded := AdventurePlayer.from_dict(saved)
	assert_not_null(loaded, "a missing plugin never makes the save unreadable")
	if loaded == null: return
	assert_eq(JSON.stringify(_round_trip(loaded)["regions"][BEACON.ID]), JSON.stringify(saved["regions"][BEACON.ID]),
		"the land's map kept as it was saved")
	assert_eq(loaded.expansions[BEACON.ID], AdventurePlayer._whole(saved["expansions"][BEACON.ID]), "its progress too")
	assert_eq(loaded.adventures, player.adventures, "still ticked")
	assert_true(AdventureExpansions.places(loaded.world).is_empty(), "no ship sails to it now")
	assert_false(AdventureTasks.rows(loaded).any(func(task: Dictionary) -> bool: return String(task["id"]).contains("voyage:")))
	assert_eq(AdventureExpansions.mainland_note(loaded),
		"Ships to Beacon Test Island do not sail: the plugin Beacon Test Island is not installed.")
	assert_true(AdventureExpansions.register_development(BEACON.ID, BEACON.descriptor()), "the plugin comes back")
	assert_eq(AdventureExpansions.mainland_note(loaded), "")
	assert_true(AdventureExpansions.voyage(loaded, BEACON.ID))
	assert_eq(loaded.world.fingerprint(), island, "the same island, from its saved map")
	assert_eq(loaded.expansions[BEACON.ID]["lit"], 2)


func test_a_hero_on_a_missing_lands_island_sails_home() -> void:
	var player := hero()
	assert_true(AdventureExpansions.voyage(player, BEACON.ID))
	var saved := _round_trip(player)
	AdventureExpansions.clear_development()
	var loaded := AdventurePlayer.from_dict(saved)
	assert_not_null(loaded)
	if loaded == null: return
	assert_eq(AdventureRegions.id(loaded.world), BEACON.ID)
	var point: Array = loaded.world.expansion["port"]
	var port := Vector2i(int(point[0]), int(point[1]))
	assert_eq(AdventureExpansions.marker(loaded.world, port), BEACON.ID + ":port", "its harbor still stands")
	var pane := AdventureExpansions.describe(loaded, port)
	assert_eq(pane["kind"], "region_port")
	assert_eq(pane["name"], "Ship home")
	assert_eq(pane["actions"][0], [AdventureExpansions.HOME_ACTION, "Sail to Shandalar", true])
	assert_string_contains(" ".join(pane["lines"]), "Beacon Test Island")
	assert_string_contains(" ".join(pane["lines"]), "Your progress here is kept")
	var castle := AdventureExpansions.stranded_place(loaded, "castle")
	assert_eq(castle["kind"], "region_castle")
	assert_eq(castle["actions"], [[AdventureExpansions.LEAVE_ACTION, "Leave the castle", true]])
	var here := AdventureTasks.rows(loaded).filter(func(task: Dictionary) -> bool: return task["region"] == BEACON.ID)
	assert_eq(here.map(func(task: Dictionary) -> String: return task["id"]), [BEACON.ID + "/return"], "only the way home")
	assert_eq(AdventureExpansions.status_lines(loaded), [] as Array[String])
	assert_true(AdventureExpansions.is_action(AdventureExpansions.HOME_ACTION))
	assert_true(AdventureExpansions.is_action(AdventureExpansions.LEAVE_ACTION))
	var screen := _screen(loaded)
	assert_true(AdventureExpansions.act(screen, AdventureExpansions.LEAVE_ACTION, castle))
	assert_eq(screen.get(&"calls"), ["after_leaving", "sync_rest"])
	screen.set(&"calls", [])
	assert_true(AdventureExpansions.act(screen, AdventureExpansions.HOME_ACTION, pane))
	assert_true(AdventureRegions.mainland(loaded), "home")
	assert_eq(screen.get(&"calls"), ["show_player", "autosave", "after_leaving", "sync_rest"])
	assert_eq(String(loaded.journal.back().get("text", "")), "Returned to Shandalar's mainland.")
	assert_true(loaded.regions.has(BEACON.ID), "the island's map is kept for the plugin's return")


func test_an_unknown_lands_record_is_carried_within_its_bounds() -> void:
	assert_true(ExpansionContract.opaque_progress({"anything": [1, {"x": "y"}], "liberated": true}))
	assert_false(ExpansionContract.opaque_progress([1]))
	assert_false(ExpansionContract.opaque_progress({1: 2}), "its keys words")
	var deep: Variant = 1
	for n in 40: deep = [deep]
	assert_false(ExpansionContract.opaque_progress({"deep": deep}))
	assert_false(ExpansionContract.opaque_progress({"long": "x".repeat(ExpansionContract.OPAQUE_BYTES)}))
	var saved := _round_trip(hero([]))
	saved["expansions"] = {"lost_land": {"anything": [1, {"x": "y"}]}}
	var loaded := AdventurePlayer.from_dict(saved)
	assert_not_null(loaded, "an unknown land in a save once made the whole save unreadable")
	assert_eq(loaded.expansions["lost_land"], {"anything": [1, {"x": "y"}]})


func test_a_plugins_progress_schema_declares_its_switches() -> void:
	var plugin := {"plugin": true, "title": "T", "progress_schema": {"quests": 5, "max_stage": 2, "max_pending": 60, "flags": ["liberated"]}}
	assert_true(ExpansionContract.valid_progress(plugin, {"quests": [0, 1], "pending": [], "liberated": true}),
		"a plugin's own switch: its finale is its own")
	assert_true(ExpansionContract.valid_progress(plugin, {"quests": [], "pending": [], "stages": {"0": 2}, "reward_choices": []}))
	assert_false(ExpansionContract.valid_progress(plugin, {"quests": [], "pending": [], "liberated": "yes"}))
	assert_false(ExpansionContract.valid_progress(plugin, {"quests": [], "pending": [], "stages": {"0": 3}}))
	assert_false(ExpansionContract.valid_progress(plugin, {"quests": [5], "pending": []}))
	var finale := plugin.duplicate(true)
	finale["progress_schema"]["complete_flags"] = ["liberated"]
	assert_false(ExpansionContract.valid_progress(finale, {"quests": [0, 1], "pending": [], "liberated": true}),
		"a switch its finale sets with every quest done: never on before")
	assert_true(ExpansionContract.valid_progress(finale, {"quests": [0, 1, 2, 3, 4], "pending": [], "liberated": true}))
	assert_true(ExpansionContract.valid_progress(finale, {"quests": [0, 1], "pending": [], "liberated": false}))
	finale["progress_schema"]["complete_flags"] = []
	assert_true(ExpansionContract.valid_progress(finale, {"quests": [0], "pending": [], "liberated": true}), "none named: none held")
	# Each quest its own longest stage (the lead's ruling, after RV2-2): past
	# its own, a version's change, held; without the list, the longest's.
	var limits := {"plugin": true, "title": "T", "progress_schema": {"quests": 3, "max_stage": 2, "flags": [],
		"stage_limits": [2, 1, 0]}}
	assert_true(ExpansionContract.valid_progress(limits, {"quests": [], "pending": [], "stages": {"0": 2, "1": 1}}))
	assert_false(ExpansionContract.valid_progress(limits, {"quests": [], "pending": [], "stages": {"1": 2}}), "past quest 1's own")
	assert_false(ExpansionContract.valid_progress(limits, {"quests": [], "pending": [], "stages": {"2": 1}}), "past quest 2's own")
	assert_eq(ExpansionContract.progress_state(limits, {"quests": [], "pending": [], "stages": {"1": 2}}), ExpansionContract.CHANGED)
	(limits["progress_schema"] as Dictionary).erase("stage_limits")
	assert_true(ExpansionContract.valid_progress(limits, {"quests": [], "pending": [], "stages": {"1": 2, "2": 1}}), "the longest's")
	var plain := {"title": "T", "progress_schema": {"quests": 5, "max_stage": 2}}
	assert_true(ExpansionContract.valid_progress(plain, {"quests": [0, 1], "pending": [], "liberated": true}),
		"no switch declared, none checked: the built-in Refuge's own rule is gone")
	assert_true(ExpansionContract.valid_progress({}, {"whatever": 1}), "nothing describes it: carried")


func test_the_mainland_note_says_why_a_ticked_land_does_not_sail() -> void:
	var descriptor := BEACON.descriptor()
	descriptor["packs"] = ["pack-3"]
	AdventureExpansions.clear_development()
	assert_true(AdventureExpansions.register_development(BEACON.ID, descriptor))
	var player := hero([BEACON.ID], [])
	assert_eq(AdventureExpansions.mainland_note(player),
		"Ships to Beacon Test Island do not sail: the plugin Beacon Test Island needs %s." % AdventurePacks.title("pack-3"))
	CardPacks.set_enabled("pack-3", true)
	var sailing := hero([BEACON.ID], ["pack-3"] as Array[String])
	assert_eq(AdventureExpansions.mainland_note(sailing), "", "every ticked land sails")
	assert_true(AdventureExpansions.voyage(sailing, BEACON.ID))
	assert_eq(AdventureExpansions.mainland_note(sailing), "", "off the mainland its harbor says it")
	ZIPS.copy_fixture(EMPTY.path_join("tiny_isle"), {"plugin.json": ZIPS.manifest_bytes({"api_version": 9})})
	AdventurePlugins.scan()
	var refused := hero([])
	refused.adventures = [{"id": "tiny_isle", "version": "0.1.0", "name": "Tiny Isle (loader fixture)"}]
	assert_eq(AdventureExpansions.mainland_note(refused),
		"Ships to Tiny Isle (loader fixture) do not sail: the plugin Tiny Isle (loader fixture) is refused.")
	assert_eq(AdventureExpansions.mainland_note(hero([])), "", "no land ticked")
	assert_eq(AdventureExpansions.mainland_note(null), "")


func test_a_pack_never_waits_for_a_land() -> void:
	var descriptor := BEACON.descriptor()
	descriptor["packs"] = ["pack-3"]
	descriptor["cards_unlock"] = "complete"
	AdventureExpansions.clear_development()
	assert_true(AdventureExpansions.register_development(BEACON.ID, descriptor))
	CardPacks.set_enabled("pack-3", true)
	var player := hero([BEACON.ID], ["pack-3"] as Array[String])
	assert_true(AdventurePacks.offers_cards(player, "pack-3"), "the pack's cards from the first day (§0.2)")
	assert_eq(AdventurePacks.adventures("pack-3"), [BEACON.ID] as Array[String])
	CardPacks.set_enabled("pack-3", false)
	assert_false(AdventurePacks.offers_cards(player, "pack-3"), "a pack switched off gives none, as ever")
	assert_false(AdventureExpansions.enabled_for(player, BEACON.ID))
