extends GutTest
## THE ADVENTURE PLUGINS' REGISTRY (adventure plugins, 2026-11-10; the
## spec's §1, §2 and §4): the folders searched in order, the first copy of
## an id winning and the later ones shadowed, the checks in stages (the
## package, the manifest, its files list, the content), the rows the
## Embark's list reads, the descriptor [AdventureExpansions] reads, and the
## pictures and tunes decoded from a plugin's own bytes. The content schema
## is stood in for by the test's own reader ([member AdventurePlugins.content_reader]);
## the schema's own tests are its builder's.

const ZIPS := preload("res://tests/support/plugin_zips.gd")
const OPTIONS := preload("res://game/options_screen.gd")
const FIXTURE := ZIPS.FIXTURE
const FIRST := "user://plugin_registry_tests/first"
const SECOND := "user://plugin_registry_tests/second"

var _calls: Array = []


func before_each() -> void:
	_calls.clear()
	DirAccess.make_dir_recursive_absolute(FIRST)
	DirAccess.make_dir_recursive_absolute(SECOND)
	AdventurePlugins.folders_override = [FIRST, SECOND] as Array[String]
	AdventurePlugins.content_reader = func(manifest: Dictionary, files: Dictionary) -> Dictionary:
		_calls.append(manifest.get("id", ""))
		return ZIPS.reader(manifest, files)


func after_each() -> void:
	ZIPS.remove("user://plugin_registry_tests")
	Settings.clear_value(GamePaths.KEY_EXPANDED_ADVENTURE)
	AdventurePlugins.folders_override = [] as Array[String]
	AdventurePlugins.content_reader = Callable()
	AdventurePlugins.scan()


func _scan_with(folder_files := {}, zips := {}) -> void:
	for path: String in folder_files:
		ZIPS.copy_fixture(path, folder_files[path])
	for path: String in zips:
		ZIPS.zip_folder(FIXTURE, path, "Top", zips[path])
	AdventurePlugins.scan()


func test_a_valid_plugins_row_carries_its_manifests_words() -> void:
	_scan_with({FIRST.path_join("tiny_isle"): {}})
	var rows := AdventurePlugins.all()
	assert_eq(rows.size(), 1)
	var row: Dictionary = rows[0]
	assert_eq(row["id"], "tiny_isle")
	assert_eq(row["name"], "Tiny Isle (loader fixture)")
	assert_eq(row["version"], "0.1.0")
	assert_eq(row["api"], 1)
	assert_eq(row["kind"], "folder")
	assert_eq(row["path"], FIRST.path_join("tiny_isle"))
	assert_string_contains(String(row["description"]), "loader's own test plugin")
	assert_eq(row["authors"], ["Shandalar Godot tests"] as Array[String])
	assert_string_contains(String(row["license"]), "GPL-3.0")
	assert_string_contains(String(row["learning_note"]), "not a playable land")
	assert_eq(row["requires"], {"card_packs": []})
	assert_eq(row["problems"], [] as Array[String])
	assert_eq(row["shadowed"], [] as Array[String])
	assert_true(AdventurePlugins.valid("tiny_isle"))
	assert_eq(AdventurePlugins.ids(), ["tiny_isle"] as Array[String])
	assert_eq(AdventurePlugins.refusal("tiny_isle"), "")
	assert_true((AdventurePlugins.data("tiny_isle")["files"] as Array).has("music/tiny_isle_tide.ogg"),
		"the content stage was handed every file, pictures and music too")
	assert_eq(_calls, ["tiny_isle"])
	row["name"] = "changed"
	assert_eq(AdventurePlugins.all()[0]["name"], "Tiny Isle (loader fixture)", "rows are copies")


func test_the_descriptor_is_the_schemas_with_the_manifests_word_for_the_rest() -> void:
	_scan_with({FIRST.path_join("tiny_isle"): {}})
	var info := AdventurePlugins.descriptor("tiny_isle")
	assert_true(info["plugin"])
	assert_eq(info["id"], "tiny_isle")
	assert_eq(info["title"], "Tiny Isle")
	assert_eq(info["castle_name"], "Tiny Keep")
	assert_eq(info["salt"], 7)
	assert_eq(info["palette"], "shandalar")
	assert_false(info["mana_links"])
	assert_eq(info["packs"], [] as Array[String])
	assert_eq(info["pack"], "")
	assert_eq(info["pictures"], {"tiny_isle_harbor": "art/tiny_isle_harbor.png"}, "the schema's own word kept")
	assert_false(info.has("provider"), "a plugin names no script at all")
	assert_false(info.has("cards_unlock"), "no plugin holds a pack's cards back")
	assert_eq(AdventurePlugins.descriptor("absent"), {})


func test_the_first_copy_of_an_id_wins_and_later_copies_are_shadowed() -> void:
	_scan_with({SECOND.path_join("tiny_isle"): {}}, {FIRST.path_join("Tiny.zip"): {}})
	var rows := AdventurePlugins.all()
	assert_eq(rows.size(), 1, "one row an id")
	assert_eq(rows[0]["path"], FIRST.path_join("Tiny.zip"), "the first folder searched wins")
	assert_eq(rows[0]["kind"], "zip")
	assert_eq(rows[0]["shadowed"], [SECOND.path_join("tiny_isle")] as Array[String])
	assert_eq(_calls, ["tiny_isle"], "a shadowed copy is never read further")
	ZIPS.remove(FIRST.path_join("Tiny.zip"))
	AdventurePlugins.scan()
	assert_eq(AdventurePlugins.all()[0]["path"], SECOND.path_join("tiny_isle"), "the next copy then")


func test_each_folder_offers_its_zips_and_plugin_folders_by_name() -> void:
	ZIPS.zip_folder(FIXTURE, FIRST.path_join("b.zip"))
	ZIPS.copy_fixture(FIRST.path_join("a_folder"))
	DirAccess.make_dir_recursive_absolute(FIRST.path_join("GUIDE"))
	var file := FileAccess.open(FIRST.path_join("README.txt"), FileAccess.WRITE)
	file.store_string("For players.")
	file.close()
	assert_eq(AdventurePlugins.candidates(FIRST), [FIRST.path_join("b.zip"), FIRST.path_join("a_folder")] as Array[String],
		"the guide and the README are passed over")
	assert_eq(AdventurePlugins.candidates("user://plugin_registry_tests/absent"), [] as Array[String])


func test_the_checks_stop_at_the_first_stage_with_a_problem() -> void:
	var path := FIRST.path_join("staged")
	_scan_with({path: {"plugin.json": ZIPS.manifest_bytes({"colour": "red"}), "evil.gd": "extends Node".to_utf8_buffer()}})
	var problems: Array = AdventurePlugins.all()[0]["problems"]
	assert_eq(problems.size(), 1, "the package's problem alone: %s" % [problems])
	assert_string_contains(String(problems[0]), "evil.gd: this kind of file is not allowed")
	assert_eq(AdventurePlugins.all()[0]["id"], "tiny_isle", "a refused plugin's row still names it")
	ZIPS.remove(path)
	_scan_with({path: {"plugin.json": ZIPS.manifest_bytes({"colour": "red", "files": {"world.json": "0".repeat(64)}})}})
	problems = AdventurePlugins.all()[0]["problems"]
	assert_eq(problems, ["plugin.json: unknown field \"colour\"."] as Array[String], "the manifest's, not its files list's")
	assert_eq(_calls, [], "the content is never read for a refused plugin")
	assert_false(AdventurePlugins.valid("tiny_isle"))
	assert_eq(AdventurePlugins.refusal("tiny_isle"), "plugin.json: unknown field \"colour\".")
	assert_eq(AdventurePlugins.data("tiny_isle"), {})
	assert_eq(AdventurePlugins.descriptor("tiny_isle"), {})
	assert_null(AdventurePlugins.texture("tiny_isle", "art/tiny_isle_harbor.png"))


func test_a_manifest_that_does_not_parse_is_a_row_with_its_reason() -> void:
	_scan_with({FIRST.path_join("broken"): {"plugin.json": "{\"id\": \"tiny_isle\",".to_utf8_buffer()}})
	var row: Dictionary = AdventurePlugins.all()[0]
	assert_eq(row["id"], "", "no id it could be filed under")
	assert_eq(row["name"], "broken", "named by its folder")
	assert_string_contains(String(row["problems"][0]), "plugin.json: line 1: ")


func test_the_content_stage_refuses_with_its_own_words() -> void:
	AdventurePlugins.content_reader = func(_manifest: Dictionary, _files: Dictionary) -> Dictionary:
		return {"data": {}, "problems": ["quests.json: quest 1 names no giver."] as Array[String]}
	_scan_with({FIRST.path_join("tiny_isle"): {}})
	assert_false(AdventurePlugins.valid("tiny_isle"))
	assert_eq(AdventurePlugins.all()[0]["problems"], ["quests.json: quest 1 names no giver."] as Array[String])


func test_manifest_problems_name_each_field() -> void:
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE.path_join("plugin.json")))
	assert_eq(AdventurePlugins.manifest_problems(good), [] as Array[String], "the fixture's manifest is whole")
	assert_eq(AdventurePlugins.manifest_problems([good]), ["plugin.json: must be one JSON object { ... }."] as Array[String])
	var cases := [
		[{"colour": "red"}, "unknown field \"colour\""],
		[{"region": null}, "the field \"region\" is missing"],
		[{"plugin_format": 2}, "plugin_format must be 1"],
		[{"api_version": 2}, "This plugin needs plugin API 2; this game reads API 1. A newer game is needed."],
		[{"api_version": 0.5}, "api_version must be a whole number"],
		[{"id": "Bad-Id"}, "id must be 1 to 40"],
		[{"id": "mainland"}, "id must be 1 to 40"],
		[{"id": "9lives"}, "id must be 1 to 40"],
		[{"id": "a".repeat(41)}, "id must be 1 to 40"],
		[{"name": ""}, "name must be non-empty text"],
		[{"description": "x".repeat(301)}, "description must be text of at most 300"],
		[{"version": "1.0.0-beta"}, "version must be numbers and dots"],
		[{"minimum_game_version": "99.0"}, "This plugin needs game version 99.0 or newer; this is %s." % AdventurePlugins.game_version()],
		[{"authors": []}, "authors must be a list of 1 to 16 names"],
		[{"authors": [""]}, "authors must be a list"],
		[{"authors": "Me"}, "authors must be a list"],
		[{"requires": {"card_packs": [{"id": "pack-1"}]}}, "pack-1 is never part of an adventure"],
		[{"requires": {"card_packs": [{"id": "pack-99"}]}}, "this game knows no card pack \"pack-99\""],
		[{"requires": {"card_packs": [{"id": "pack-2"}, {"id": "pack-2"}]}}, "pack-2 is named twice"],
		[{"requires": {"card_packs": [{"id": "pack-2", "min_version": "one"}]}}, "pack-2's min_version must be numbers"],
		[{"requires": {"card_packs": [{"id": "pack-2", "max": 3}]}}, "requires.card_packs: unknown field \"max\""],
		[{"requires": {"lands": []}}, "requires: unknown field \"lands\""],
		[{"requires": {"card_packs": ["pack-2"]}}, "each of requires.card_packs is"],
		[{"region": {"castle_name": "Keep"}}, "region.title must be non-empty text"],
		[{"region": {"title": "T", "salt": -1}}, "region.salt must be a whole number"],
		[{"region": {"title": "T", "mana_links": "no"}}, "region.mana_links must be true or false"],
		[{"region": {"title": "T", "palette": "neon"}}, "region.palette \"neon\" is not one of the game's palettes"],
		[{"region": {"title": "T", "palette": 3}}, "region.palette must be a palette's name or a palette object"],
		[{"region": {"title": "T", "weather": "rain"}}, "region: unknown field \"weather\""],
		[{"files": {"world.json": "ABC"}}, "files: \"world.json\" needs its SHA-256"],
		[{"files": []}, "files must be an object"],
	]
	for case: Array in cases:
		var manifest := good.duplicate(true)
		var changes: Dictionary = case[0]
		for key: String in changes:
			if changes[key] == null:
				manifest.erase(key)
			else:
				manifest[key] = changes[key]
		var problems := AdventurePlugins.manifest_problems(manifest)
		assert_true(problems.any(func(p: String) -> bool: return p.contains(case[1])), "%s → %s" % [changes, problems])
	var objects := good.duplicate(true)
	objects["region"]["palette"] = {"name": "Mine"}
	assert_eq(AdventurePlugins.manifest_problems(objects), [] as Array[String], "a palette object is the schema's to check")


func test_the_files_list_holds_every_file_to_its_hash() -> void:
	var read := PluginPackage.read(FIXTURE)
	var listed := {}
	for rel: String in read["files"]:
		if rel != "plugin.json":
			listed[rel] = PluginPackage.sha256(read["files"][rel])
	_scan_with({FIRST.path_join("listed"): {"plugin.json": ZIPS.manifest_bytes({"files": listed})}})
	assert_true(AdventurePlugins.valid("tiny_isle"), "every file listed with its hash: %s" % [AdventurePlugins.all()[0]["problems"]])
	var manifest: Dictionary = JSON.parse_string(ZIPS.manifest_bytes({"files": listed}).get_string_from_utf8())
	var files: Dictionary = (read["files"] as Dictionary).duplicate()
	files["world.json"] = "{\"changed\": true}".to_utf8_buffer()
	files["extra.txt"] = "not listed".to_utf8_buffer()
	files.erase("foes.json")
	var problems := AdventurePlugins.integrity_problems(manifest, files)
	assert_eq(problems, ["foes.json: listed in plugin.json's files but not in the plugin.",
		"world.json: its SHA-256 is not the one plugin.json's files list gives (the file changed after export).",
		"extra.txt: not in plugin.json's files list."] as Array[String])
	manifest.erase("files")
	assert_eq(AdventurePlugins.integrity_problems(manifest, files), [] as Array[String], "the list is optional")


func test_pictures_and_tunes_are_decoded_from_the_plugins_bytes() -> void:
	_scan_with({FIRST.path_join("tiny_isle"): {}}, {SECOND.path_join("Shadowed.zip"): {}})
	var picture := AdventurePlugins.texture("tiny_isle", "art/tiny_isle_harbor.png")
	assert_not_null(picture)
	assert_eq(picture.get_size(), Vector2(8, 4))
	assert_same(AdventurePlugins.texture("tiny_isle", "art/tiny_isle_harbor.png"), picture, "decoded once")
	var tune := AdventurePlugins.stream("tiny_isle", "music/tiny_isle_tide.ogg")
	assert_true(tune is AudioStreamOggVorbis)
	assert_true(tune != null and (tune as AudioStreamOggVorbis).loop, "a land's track loops")
	assert_null(AdventurePlugins.texture("tiny_isle", "art/absent.png"))
	assert_null(AdventurePlugins.texture("tiny_isle", "music/tiny_isle_tide.ogg"), "a tune is no picture")
	assert_null(AdventurePlugins.stream("tiny_isle", "art/tiny_isle_harbor.png"), "a picture is no tune")
	assert_null(AdventurePlugins.texture("other", "art/tiny_isle_harbor.png"))
	ZIPS.remove(FIRST.path_join("tiny_isle"))
	ZIPS.zip_folder(FIXTURE, FIRST.path_join("Tiny.zip"), "Top")
	AdventurePlugins.scan()
	var from_zip := AdventurePlugins.texture("tiny_isle", "art/tiny_isle_harbor.png")
	assert_not_null(from_zip, "from a zip's entry")
	assert_ne(from_zip, picture, "a rescan lets the old pictures go")


func test_a_file_changed_since_the_scan_is_not_trusted() -> void:
	var path := FIRST.path_join("tiny_isle")
	_scan_with({path: {}})
	var changed := PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13])
	var file := FileAccess.open(path.path_join("art/tiny_isle_harbor.png"), FileAccess.WRITE)
	file.store_buffer(changed)
	file.close()
	assert_null(AdventurePlugins.texture("tiny_isle", "art/tiny_isle_harbor.png"), "not the bytes the scan checked")


func test_a_rescan_counts_and_tells_the_lands() -> void:
	var before := AdventurePlugins.revision
	var lands := AdventureExpansions.revision
	AdventurePlugins.scan()
	assert_eq(AdventurePlugins.revision, before + 1)
	assert_gt(AdventureExpansions.revision, lands, "the lands' caches are let go too")


func test_the_folders_are_searched_in_order() -> void:
	AdventurePlugins.folders_override = [] as Array[String]
	var folders := AdventurePlugins.folders()
	assert_eq(folders[0], GamePaths.expanded_adventure_folder(), "the player's folder first")
	assert_eq(GamePaths.expanded_adventure_folder(), "user://expanded_adventure", "by default")
	assert_false(Settings.has_value(GamePaths.KEY_EXPANDED_ADVENTURE), "reading the default writes nothing")
	assert_true(folders[1].ends_with("/expanded_adventure"), "then beside the game: " + folders[1])
	assert_true(folders.has("res://expanded_adventure"), "a development run reads the repository's")
	assert_true(folders[folders.size() - 1].ends_with("shandalar-packs/expanded_adventure"))
	Settings.set_value(GamePaths.KEY_EXPANDED_ADVENTURE, "~/My Plugins/", false)
	assert_eq(AdventurePlugins.folders()[0], GamePaths.expand("~/My Plugins"), "the settings key moves it")


func test_words_and_versions() -> void:
	for id in ["refuge", "a", "tiny_isle", "x" + "1".repeat(39)]:
		assert_true(AdventurePlugins.valid_id(id), id)
	for id in ["", "mainland", "Refuge", "_x", "1x", "a-b", "a b", "x" + "1".repeat(40)]:
		assert_false(AdventurePlugins.valid_id(id), id)
	assert_true(AdventurePlugins.valid_version("0.60.19"))
	for text in ["", "1.", ".1", "1..2", "v1", "1.2.3.4.5", "+1", "1.-2"]:
		assert_false(AdventurePlugins.valid_version(text), text)
	assert_eq(AdventurePlugins.compare_versions("0.60.19", "0.60.19"), 0)
	assert_eq(AdventurePlugins.compare_versions("0.60.2", "0.60.19"), -1, "number by number, not letter by letter")
	assert_eq(AdventurePlugins.compare_versions("0.61", "0.60.19"), 1)
	assert_eq(AdventurePlugins.compare_versions("1.0", "1.0.0"), 0)


func test_the_options_row_names_the_folder_and_its_plugins() -> void:
	assert_eq(OPTIONS.adventure_plugins_line("~/x/expanded_adventure", 0), "Adventure plugins folder: ~/x/expanded_adventure — none found")
	assert_eq(OPTIONS.adventure_plugins_line("~/x/expanded_adventure", 2), "Adventure plugins folder: ~/x/expanded_adventure — 2 found")


func test_no_plugin_path_reaches_the_resource_loader() -> void:
	for path in ["res://game/adventure/plugins/adventure_plugins.gd", "res://game/adventure/plugins/plugin_package.gd"]:
		var source := FileAccess.get_file_as_string(path)
		for word in ["load_resource_pack", "ResourceLoader", "preload(", " load(", "\tload(", "(load("]:
			assert_false(source.contains(word), "%s holds %s" % [path, word])
	for provider in ["user://expanded_adventure/evil.gd", ProjectSettings.globalize_path("res://tools/expansion_testing/beacon_region.gd"),
			"res://../outside.gd"]:
		assert_false(ExpansionContract.valid_descriptor({"provider": provider, "title": "T", "progress_schema": {"quests": 1}}), provider)
	assert_true(ExpansionContract.valid_descriptor({"plugin": true, "title": "T", "progress_schema": {"quests": 1, "flags": ["liberated"]},
		"initial_progress": {"quests": [], "pending": [], "liberated": false}}), "a plugin's names no script")


## A CARD PACK OLDER THAN THE PLUGIN ASKS (adventure plugins, 2026-11-10;
## P4's finding): `requires.card_packs[].min_version` held to the installed
## pack's version as the game compares pack versions — not a refusal (the
## plugin is whole), but its ships do not sail, as for a pack missing, and
## the row's `pack_status` says so for the Embark's window.
func test_a_pack_older_than_the_plugin_asks_keeps_its_ships_in_harbor() -> void:
	CardPacks.set_enabled("pack-2", true)
	var installed := String(CardPacks.info("pack-2").get("version", ""))
	assert_ne(installed, "", "the test's Pack 2 has a version")
	_scan_with({FIRST.path_join("tiny_isle"): {"plugin.json": ZIPS.manifest_bytes(
		{"requires": {"card_packs": [{"id": "pack-2", "min_version": "99.0.0"}]}})}})
	assert_true(AdventurePlugins.valid("tiny_isle"), "a pack too old refuses nothing: %s" % AdventurePlugins.refusal("tiny_isle"))
	var status: Array = AdventurePlugins.all()[0]["pack_status"]
	assert_eq(status.size(), 1)
	var need: Dictionary = status[0] if not status.is_empty() else {}
	assert_eq(need.get("id"), "pack-2")
	assert_eq(need.get("min_version"), "99.0.0")
	assert_eq(need.get("version"), installed)
	assert_true(need.get("installed", false))
	assert_true(need.get("enabled", false))
	assert_false(need.get("new_enough", true), "older than asked")
	assert_eq(need.get("title"), AdventurePacks.title("pack-2"))
	assert_eq(AdventurePlugins.pack_status("tiny_isle"), status)
	assert_false(AdventureExpansions.enabled("tiny_isle"), "its ships do not sail")
	var setup := AdventureSetup.new()
	setup.adventures = ["tiny_isle"] as Array[String]
	setup.packs = ["pack-2"] as Array[String]
	setup.seed_text = "48271"
	var record := setup.resolve({"pack-2": installed})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	assert_eq(AdventureExpansions.mainland_note(hero),
		"Ships to Tiny Isle do not sail: the plugin Tiny Isle (loader fixture) needs %s %s or newer (installed %s)." % [
			AdventurePacks.title("pack-2"), "99.0.0", installed])
	ZIPS.remove(FIRST.path_join("tiny_isle"))
	_scan_with({FIRST.path_join("tiny_isle"): {"plugin.json": ZIPS.manifest_bytes(
		{"requires": {"card_packs": [{"id": "pack-2", "min_version": installed}]}})}})
	assert_true(AdventurePlugins.all()[0]["pack_status"][0]["new_enough"], "the very version asked")
	assert_true(AdventureExpansions.enabled("tiny_isle"))
	assert_eq(AdventureExpansions.mainland_note(hero), "", "it sails")
	ZIPS.remove(FIRST.path_join("tiny_isle"))
	_scan_with({FIRST.path_join("tiny_isle"): {}})
	assert_eq(AdventurePlugins.all()[0]["pack_status"], [], "no pack asked: none listed")
