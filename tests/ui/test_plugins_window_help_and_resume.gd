extends GutTest
## THE ADVENTURE PLUGINS IN THE HELP AND ON RESUME (adventure plugins,
## 2026-11-10): the Help's own page — what a plugin is, where it goes, how
## it is ticked, what a missing one does, the learning demo, the authors'
## guide — named from the Embark's page and the saves' page; and a hero
## taken up on a land whose plugin is missing is told why it is quiet and
## the way home (the land is the development fixture, registered and taken
## away as a plugin is installed and removed). With them the casting page's
## line for the mana a click on a many-colored source gives (issue #7).

const BEACON := preload("res://tools/expansion_testing/beacon_region.gd")
const ZIPS := preload("res://tests/support/plugin_zips.gd")
const PROTOTYPE := "res://expanded_adventure/Fallen_Empires_Refuge_prototype"
const SAVES := "user://plugins_window_resume"
const EMPTY := "user://plugins_window_resume_none"
const REFUGE_ROOT := "user://plugins_window_resume_refuge"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(EMPTY)
	AdventurePlugins.folders_override = [EMPTY] as Array[String]
	AdventurePlugins.scan()


func after_each() -> void:
	AdventureExpansions.clear_development()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	DirAccess.remove_absolute(EMPTY)
	ZIPS.remove(REFUGE_ROOT)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	AdventurePlayer.forget_saves()
	AdventurePlugins.folders_override = [] as Array[String]
	AdventurePlugins.scan()


func _page(title: String) -> String:
	for page in HelpPages.pages():
		if String(page["title"]) == title:
			var out := PackedStringArray()
			for block in page["blocks"]:
				out.append(String(block.get("text", "")))
			return "\n".join(out)
	return ""


func test_the_help_has_a_page_for_the_adventure_plugins() -> void:
	var pages := HelpPages.pages()
	var titles: Array[String] = []
	for page in pages:
		titles.append(String(page["title"]))
	var at := titles.find("Adventure plugins")
	assert_gt(at, 0, "the page")
	assert_eq(titles[at - 1], "Saved adventures", "after the adventure's own pages")
	var listed := false
	for block in pages[0]["blocks"]:
		for entry in block.get("entries", []):
			listed = listed or (String(entry["title"]) == "Adventure plugins" and int(entry["page"]) == at)
	assert_true(listed, "in the contents, under The adventure")
	var text := _page("Adventure plugins")
	for words in ["data only", "never runs anything from a plugin", "expanded_adventure folder",
			"The Meta Quest, Android and browser packages carry no guide",
			"Windows, Linux, macOS, Raspberry Pi, Steam Deck and ArkOS packages",
			"Adventure plugins folder line", "expanded_adventure_folder key", "Expanded adventure plugins...",
			"ticked, not ticked or not installed", "the card packs it needs are ticked with it",
			"the plugins that need it are unticked too", "cannot be ticked", "Rescan", "Open folder",
			"a pad's B", "listed greyed, with every problem", "a ship home at its port",
			"kept as they were", "The Last Refuge (Fallen Empires prototype)", "Pack 2 · Fallen Empires",
			"game-design and learning demo", "not official Magic canon", "GUIDE/index.html", "needs no internet"]:
		assert_string_contains(text, words)
	assert_false(text.contains("--expanded-adventure"), "the retired flag is never named")
	assert_false(text.contains("colour"))
	var embark := _page("Shandalar — a new adventure")
	assert_string_contains(embark, "Expanded adventure plugins..., at the foot of the card packs")
	assert_string_contains(embark, "See Adventure plugins.")
	assert_false(embark.to_lower().contains("island"), "the Embark's page keeps to the Embark")
	assert_string_contains(_page("Saved adventures"), "An adventure plugin that has gone missing is no bar")


func test_the_casting_page_tells_the_mana_a_many_colored_source_gives() -> void:
	var casting := _page("Casting spells and the Spell Chain")
	assert_string_contains(casting, "clicking a dual land, Birds of Paradise or City of Brass taps it for the color the cost still needs")
	assert_string_contains(casting, "(Fellwar Stone always asks)")


func test_a_hero_taken_up_on_a_missing_plugins_island_is_told_the_way_home() -> void:
	assert_true(AdventureExpansions.register_development(BEACON.ID, BEACON.descriptor()), "the fixture land")
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	setup.player_name = "Wayfarer"
	setup.adventures = [BEACON.ID] as Array[String]
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(player)
	assert_eq(LoadAdventureScreen.stranded_note(player), "", "on the mainland the world says it itself")
	assert_true(AdventureExpansions.voyage(player, BEACON.ID))
	assert_eq(LoadAdventureScreen.stranded_note(player), "", "its plugin is here")
	var path := player.autosave()
	assert_ne(path, "", "saved on the island")
	AdventureExpansions.clear_development()
	var refusal: Array[String] = []
	var screen := LoadAdventureScreen.open_save(path, refusal)
	assert_not_null(screen, "a missing plugin never refuses the save")
	if screen == null:
		return
	assert_eq(refusal, [] as Array[String])
	assert_string_contains(screen.arrival, "Wayfarer takes up the adventure again.")
	assert_string_contains(screen.arrival, "\nThe adventure plugin Beacon Test Island is not installed or cannot be read, so Beacon Test Island rests as you left it.")
	assert_string_contains(screen.arrival, "Your progress here is kept.")
	assert_string_contains(screen.arrival, "The ship can always take you home.")
	assert_string_contains(screen.arrival, " ".join(PackedStringArray(AdventureExpansions.stranded_place(screen.player, "port")["lines"])),
		"in the words of its port's own pane")
	screen.free()


## RV2-5: a land HELD — its plugin installed, but in a version that cannot
## read the land as it was saved (here a town moved by 1.1.0) — is as quiet
## as a missing one's, and a hero taken up on it is told so: the port's own
## held words, the version saved and the version installed.
func test_a_hero_taken_up_on_a_held_island_is_told_why() -> void:
	var packs_before := CardPacks.is_enabled(FallenEmpiresPack.ID)
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	AdventurePlayer.saves_folder = SAVES
	_install_refuge("1.0.0")
	var setup := AdventureSetup.new()
	setup.adventures = ["refuge"] as Array[String]
	setup.packs = ["pack-2"] as Array[String]
	setup.seed_text = "48271"
	setup.player_name = "Wayfarer"
	var record := setup.resolve({"pack-2": "1"})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(player)
	assert_true(AdventureExpansions.voyage(player, "refuge"), "to the island")
	var path := player.autosave()
	assert_eq(LoadAdventureScreen.stranded_note(player), "", "its plugin reads it")
	# 1.1.0 with Havenwood moved from town slot 5 to slot 6 (as the plugin
	# update tests move it).
	_install_refuge("1.1.0", {
		"world.json": func(world: Dictionary) -> void:
			for town: Dictionary in world["towns"]["list"]:
				if int(town["slot"]) == 5: town["slot"] = 6
			world["objectives"]["channel"]["exclude"] = [1, 2, 3, 4, 6],
		"quests.json": func(quests: Dictionary) -> void:
			for quest: Dictionary in quests["quests"]:
				if int(quest["giver"]) == 5: quest["giver"] = 6
			quests["errands_off"] = [0, 1, 2, 3, 4, 6],
	})
	var refusal: Array[String] = []
	var screen := LoadAdventureScreen.open_save(path, refusal)
	CardPacks.set_enabled(FallenEmpiresPack.ID, packs_before)
	assert_not_null(screen, "a held land never refuses the save")
	if screen == null:
		return
	assert_true(AdventureExpansions.known("refuge"), "the plugin is here")
	assert_true(AdventureExpansions.held(screen.player, "refuge"), "but it cannot read the land")
	assert_string_contains(screen.arrival, "This land was saved with version 1.0.0 of the plugin The Last Refuge (Fallen Empires prototype), and the installed version 1.1.0 cannot read it, so The Last Refuge rests as you left it.")
	assert_string_contains(screen.arrival, "Put version 1.0.0 back in the expanded_adventure folder to go on.")
	assert_string_contains(screen.arrival, "The ship can always take you home.")
	screen.free()


## The Refuge prototype installed alone under the test profile as
## [param version], each of [param edits] `{rel: Callable(Dictionary)}`
## changing its JSON file.
func _install_refuge(version: String, edits := {}) -> void:
	ZIPS.remove(REFUGE_ROOT)
	var at := REFUGE_ROOT.path_join("Refuge_" + version.replace(".", "_"))
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
	AdventurePlugins.folders_override = [REFUGE_ROOT] as Array[String]
	AdventurePlugins.scan()
	assert_true(AdventurePlugins.valid("refuge"), "%s installs: %s" % [version, AdventurePlugins.refusal("refuge")])
