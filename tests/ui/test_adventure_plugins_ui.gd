extends GutTest
## THE PLUGINS' WORDS AND MUSIC ON THE WORLD SCREEN (adventure plugins,
## 2026-11-10; the second review's RV2-4, RV2-7, RV2-8): the Tasks tab says
## truly why a land's ships do not sail (a pack too old, not "enable it"),
## the Hero page names a missing plugin's land by its own title, and the
## Options' Music switch brings back a land's own track, not the title's
## tune beside it.

const ZIPS := preload("res://tests/support/plugin_zips.gd")
const BEACON := preload("res://tools/expansion_testing/beacon_region.gd")
const MUSIC := preload("res://tests/support/plugin_music_region.gd")
const PROTOTYPE := "res://expanded_adventure/Fallen_Empires_Refuge_prototype"
const ROOT := "user://plugin_ui_tests"
const SAVES := "user://plugin_ui_tests_saves"

var _pack_before: bool
var _music_before: bool


func before_each() -> void:
	_pack_before = CardPacks.is_enabled(FallenEmpiresPack.ID)
	_music_before = Settings.music_enabled()
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	AdventurePlayer.saves_folder = SAVES


func after_each() -> void:
	ZIPS.remove(ROOT)
	ZIPS.remove(SAVES)
	AdventurePlugins.folders_override = [] as Array[String]
	AdventurePlugins.scan()
	AdventureExpansions.clear_development()
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	Settings.set_value("music_enabled", _music_before, false)
	CardPacks.set_enabled(FallenEmpiresPack.ID, _pack_before)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _hero(lands: Array[String] = ["refuge"]) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.adventures = lands
	setup.packs.assign(["pack-2"] if lands.has("refuge") else [])
	setup.seed_text = "48271"
	setup.player_name = "Wayfarer"
	var record := setup.resolve({"pack-2": String(CardPacks.info("pack-2").get("version", "1"))})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(hero)
	return hero


func _refuge() -> DataRegion:
	return AdventureExpansions.provider("refuge") as DataRegion


## The prototype installed alone, its Pack 2 asked at [param least] or newer.
func _install(least := "") -> void:
	var at := ROOT.path_join("Refuge")
	for rel in ZIPS.files_of(PROTOTYPE):
		DirAccess.make_dir_recursive_absolute(at.path_join(rel).get_base_dir())
		var file := FileAccess.open(at.path_join(rel), FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(PROTOTYPE.path_join(rel)))
		file.close()
	if least != "":
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(at.path_join("plugin.json")))
		manifest["requires"]["card_packs"][0]["min_version"] = least
		var out := FileAccess.open(at.path_join("plugin.json"), FileAccess.WRITE)
		out.store_string(JSON.stringify(manifest, "\t"))
		out.close()
	AdventurePlugins.folders_override = [ROOT] as Array[String]
	AdventurePlugins.scan()
	assert_true(AdventurePlugins.valid("refuge"), AdventurePlugins.refusal("refuge"))


func _panel(player: AdventurePlayer, tab := "Tasks") -> HeroStats:
	var panel := HeroStats.new()
	panel.player = player
	add_child_autofree(panel)
	panel.tab = tab
	panel.refresh()
	await _frames(1)
	return panel


func _texts(panel: Node) -> Array[String]:
	var out: Array[String] = []
	for node in panel.find_children("*", "Label", true, false):
		out.append((node as Label).text)
	return out


func test_the_tasks_tab_names_a_pack_too_old_truly() -> void:
	var hero := _hero()
	assert_true(_refuge().travel(hero))
	assert_true(_refuge().travel(hero), "home again, the island visited")
	_install("99.0.0")
	var loaded := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(hero.to_dict())))
	assert_not_null(loaded)
	if loaded == null: return
	var panel := await _panel(loaded)
	var said := _texts(panel)
	assert_false(said.has("Enable this region's pack to travel there."), "the pack is enabled, only too old")
	var why := AdventureExpansions.sail_refusal(loaded, "refuge")
	assert_string_contains(why, "needs %s 99.0.0 or newer (installed %s)" % [AdventurePacks.title("pack-2"),
		String(CardPacks.info("pack-2").get("version", ""))])
	assert_true(said.has(why), "the mainland note's own sentence: %s" % [said])
	assert_eq(AdventureExpansions.mainland_note(loaded), why, "one land, one sentence")


func test_the_hero_page_names_a_missing_plugins_land_by_its_title() -> void:
	var hero := _hero()
	assert_true(_refuge().travel(hero))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(hero.to_dict()))
	AdventurePlugins.folders_override = [ROOT.path_join("none")] as Array[String]
	AdventurePlugins.scan()
	var loaded := AdventurePlayer.from_dict(saved)
	assert_not_null(loaded)
	if loaded == null: return
	assert_false(AdventureExpansions.known("refuge"), "the plugin is away")
	var panel := await _panel(loaded, "Hero")
	assert_string_contains(String(panel._number_values()["road"]), "(The Last Refuge)", "its title, not \"Refuge\"")
	var line := ""
	for entry in loaded.journal:
		if String(entry.get("region", "")) == "refuge":
			line = HeroStats.journal_line(entry, loaded)
			break
	assert_string_contains(line, " · The Last Refuge: ")


func test_the_music_switch_brings_back_the_lands_own_track() -> void:
	assert_true(AdventureExpansions.register_development(BEACON.ID, MUSIC.music_descriptor()))
	var hero := _hero([BEACON.ID] as Array[String])
	assert_true(AdventureExpansions.voyage(hero, BEACON.ID))
	var screen: WorldScreen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.player = hero
	add_child_autofree(screen)
	await _frames(3)
	screen.show_player(hero)
	var voice := screen.soundscape.get_node_or_null(^"RegionTune")
	assert_not_null(voice, "the land's track on arrival")
	if voice != null:
		voice.name = "Gone"
		voice.queue_free()
	await _frames(1)
	screen.hud._choose("Music")
	screen.hud._choose("Music")
	await _frames(1)
	var again := screen.soundscape.get_node_or_null(^"RegionTune") as AudioStreamPlayer
	assert_not_null(again, "the switch asks for the world's music, the land's first")
	if again != null:
		assert_same(again.stream, MUSIC.music())
