extends GutTest
## AN ADVENTURE CARRIED TO ANOTHER DEVICE AND BACK (a player on Android,
## and the owner, 2026-11-06): [AdventureTransfer] packs every file of one
## adventure into one zip, and takes such a zip in only once all of it is
## checked — the manifest, the names, the sizes, the hashes and each save
## as the game reads one.

const FOLDER := "user://adventure_tests_transfer"
const OUT := "user://adventure_tests_transfer_out"
const HALL := "user://adventure_tests_transfer_hall"

var _total := 0


func before_each() -> void:
	_total = AdventureTransfer.max_total_bytes
	AdventurePlayer.saves_folder = FOLDER
	HallOfFame.file = HALL + "/hall_of_fame.json"
	for folder in [FOLDER, OUT, HALL]:
		_wipe(folder)
		DirAccess.make_dir_recursive_absolute(folder)
	AdventurePlayer.forget_saves()


func after_each() -> void:
	AdventureTransfer.max_total_bytes = _total
	for folder in [FOLDER, OUT, HALL, AdventureTransfer.STAGING]:
		_wipe(folder)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	HallOfFame.file = HallOfFame.FILE
	AdventurePlayer.forget_saves()


func _wipe(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file_name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))
	for sub in DirAccess.get_directories_at(folder):
		_wipe(folder.path_join(sub))
	DirAccess.remove_absolute(folder)


## Adventure of [param hero] saved three ways, each twice, so each keeps
## its `.bak`: the autosave, the Quickslot and slot 2.
func _saved(hero := "Goya") -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.player_name = hero
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	var record := setup.resolve({})
	var adventure := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	adventure.gold = 432
	for twice in 2:
		adventure.autosave()
		SaveSlots.save_quick(adventure)
		SaveSlots.save_into(adventure, 2, "By the river")
	return adventure


## Every file in [param folder], `{name: bytes}`.
func _files(folder: String) -> Dictionary:
	var out := {}
	for file_name in DirAccess.get_files_at(folder):
		out[file_name] = FileAccess.get_file_as_bytes(folder.path_join(file_name))
	return out


## A zip at [param path] of [param manifest] (a record, or raw bytes) and
## [param members] `{name: bytes}`.
func _zip(path: String, manifest: Variant, members: Dictionary) -> void:
	var packer := ZIPPacker.new()
	assert_eq(packer.open(path), OK)
	if manifest != null:
		packer.start_file(AdventureTransfer.MANIFEST)
		packer.write_file(manifest if manifest is PackedByteArray
			else JSON.stringify(manifest).to_utf8_buffer())
		packer.close_file()
	for name: String in members:
		packer.start_file(name)
		packer.write_file(members[name])
		packer.close_file()
	packer.close()


## The manifest [param members] would carry for adventure [param id].
func _manifest(id: String, members: Dictionary) -> Dictionary:
	var rows: Array = []
	for name: String in members:
		var bytes: PackedByteArray = members[name]
		rows.append({"name": name, "bytes": bytes.size(), "sha256": AdventureTransfer.sha256(bytes)})
	return {"format": AdventureTransfer.FORMAT, "version": AdventureTransfer.FORMAT_VERSION,
		"adventure_id": id, "hero": "Goya", "files": rows}


func _refused(path: String, words: String) -> void:
	var read := AdventureTransfer.read_package(path, "x.zip")
	assert_false(bool(read["ok"]), words)
	assert_eq(String(read["message"]), words % "x.zip" if words.count("%s") == 1 else words)


# ---------------------------------------------------------- the round trip --

func test_three_saves_and_their_baks_go_out_and_come_back_byte_for_byte() -> void:
	var goya := _saved()
	var id := goya.adventure_id
	var before := _files(FOLDER)
	assert_eq(before.size(), 6, "three saves and three .bak copies")
	var zip := OUT.path_join("Goya.zip")
	var made := AdventureTransfer.export_to(id, zip)
	assert_true(bool(made["ok"]), String(made["message"]))
	assert_eq(int(made["saves"]), 3)
	assert_eq(String(made["hero"]), "Goya")
	assert_eq(int(made["left_out"]), 0)
	assert_false(FileAccess.file_exists(AdventureTransfer.OUTGOING), "nothing left in the game's folder")
	_wipe(FOLDER)
	AdventurePlayer.forget_saves()
	var package := AdventureTransfer.take_in(zip)
	assert_true(bool(package["ok"]), String(package["message"]))
	assert_false(FileAccess.file_exists(AdventureTransfer.INCOMING), "the checked copy gone")
	var done := AdventureTransfer.install(package)
	assert_true(bool(done["ok"]), String(done["message"]))
	assert_eq(String(done["message"]), "Imported Goya's adventure: 3 saves.")
	assert_eq(_files(FOLDER), before, "every file back, byte for byte, and nothing else")
	var back := AdventurePlayer.load_from(goya.save_path(AdventurePlayer.AUTOSAVE))
	assert_not_null(back, "the adventure loads")
	if back != null:
		assert_eq([back.adventure_id, back.name, back.gold], [id, "Goya", 432])
		assert_eq(back.world.fingerprint(), goya.world.fingerprint(), "its world as it was")


func test_the_manifest_names_each_file_with_its_size_and_hash() -> void:
	var goya := _saved()
	var zip := OUT.path_join("Goya.zip")
	assert_true(bool(AdventureTransfer.export_to(goya.adventure_id, zip)["ok"]))
	var reader := ZIPReader.new()
	assert_eq(reader.open(zip), OK)
	var manifest: Dictionary = JSON.parse_string(reader.read_file(AdventureTransfer.MANIFEST).get_string_from_utf8())
	assert_eq(manifest["format"], AdventureTransfer.FORMAT)
	assert_eq(int(manifest["version"]), AdventureTransfer.FORMAT_VERSION)
	assert_eq(manifest["adventure_id"], goya.adventure_id)
	assert_eq(manifest["hero"], "Goya")
	assert_eq(manifest["game_version"], ProjectSettings.get_setting("application/config/version"))
	assert_eq(int(manifest["save_format_version"]), AdventurePlayer.FORMAT_VERSION)
	assert_eq((manifest["files"] as Array).size(), 6)
	for row: Dictionary in manifest["files"]:
		var bytes := FileAccess.get_file_as_bytes(FOLDER.path_join(String(row["name"])))
		assert_eq(int(row["bytes"]), bytes.size(), row["name"])
		assert_eq(row["sha256"], AdventureTransfer.sha256(bytes), row["name"])
		assert_eq(reader.read_file(String(row["name"])), bytes, "stored under its own name")
	assert_eq(reader.get_files().size(), 7, "the manifest and the six files")
	reader.close()


func test_a_file_of_the_adventure_that_cannot_be_read_is_left_out_and_counted() -> void:
	var goya := _saved()
	var odd := FOLDER.path_join("%s.slot05.json" % goya.adventure_id)
	var file := FileAccess.open(odd, FileAccess.WRITE)
	file.store_string("{ cut sho")
	file.close()
	var zip := OUT.path_join("Goya.zip")
	var made := AdventureTransfer.export_to(goya.adventure_id, zip)
	assert_true(bool(made["ok"]))
	assert_eq(int(made["left_out"]), 1)
	assert_eq(int(made["saves"]), 3)
	assert_true(bool(AdventureTransfer.take_in(zip)["ok"]), "and the zip is one Import takes")


func test_one_life_mark_travels_with_the_adventure() -> void:
	var goya := _saved()
	HallOfFame.mark_one_life(goya.adventure_id, HallOfFame.BEGUN)
	var zip := OUT.path_join("Goya.zip")
	assert_true(bool(AdventureTransfer.export_to(goya.adventure_id, zip)["ok"]))
	HallOfFame.mark_one_life(goya.adventure_id, "")
	_wipe(FOLDER)
	var package := AdventureTransfer.take_in(zip)
	assert_eq(String(package["one_life"]), HallOfFame.BEGUN)
	assert_true(bool(AdventureTransfer.install(package)["ok"]))
	assert_eq(HallOfFame.one_life_state(goya.adventure_id), HallOfFame.BEGUN,
		"no copy taken elsewhere fights that battle again")


func test_the_file_name_keeps_to_safe_characters() -> void:
	assert_eq(AdventureTransfer.file_name_for("Goya", "2026-11-06"), "Shandalar adventure - Goya - 2026-11-06.zip")
	assert_eq(AdventureTransfer.file_name_for("Go/ya: *Who?*", "2026-11-06"),
		"Shandalar adventure - Go-ya- -Who-- - 2026-11-06.zip")
	assert_eq(AdventureTransfer.file_name_for("..", "2026-11-06"), "Shandalar adventure - Hero - 2026-11-06.zip")
	assert_eq(AdventureTransfer.file_name_for("Ærwyn Óg", "2026-11-06"), "Shandalar adventure - Ærwyn Óg - 2026-11-06.zip")
	assert_true(AdventureTransfer.file_name_for("Goya").begins_with("Shandalar adventure - Goya - 20"))


func test_existing_counts_the_saves_here_and_the_newest() -> void:
	var goya := _saved()
	var here := AdventureTransfer.existing(goya.adventure_id)
	assert_eq(int(here["files"]), 6)
	assert_eq(int(here["saves"]), 3)
	assert_eq(String(here["hero"]), "Goya")
	assert_ne(String(here["newest"]), "")
	assert_eq(int(AdventureTransfer.existing("Nobody-00000000")["files"]), 0)


func test_install_puts_back_what_was_there_when_a_write_fails() -> void:
	var goya := _saved()
	var zip := OUT.path_join("Goya.zip")
	assert_true(bool(AdventureTransfer.export_to(goya.adventure_id, zip)["ok"]))
	var package := AdventureTransfer.take_in(zip)
	# What is here now differs from the zip: one more save, gold changed.
	goya.gold = 7
	goya.autosave()
	var before := _files(FOLDER)
	# The quickslot's place taken by a folder: that write cannot land.
	var quick := goya.save_path(SaveSlots.QUICK_KIND)
	DirAccess.remove_absolute(quick)
	before.erase(quick.get_file())
	DirAccess.make_dir_recursive_absolute(quick)
	var done := AdventureTransfer.install(package)
	assert_false(bool(done["ok"]))
	assert_string_contains(String(done["message"]), "nothing was imported")
	DirAccess.remove_absolute(quick)
	assert_eq(_files(FOLDER), before, "every file as it was")


func test_replacing_removes_the_files_the_zip_does_not_have() -> void:
	var goya := _saved()
	var zip := OUT.path_join("Goya.zip")
	assert_true(bool(AdventureTransfer.export_to(goya.adventure_id, zip)["ok"]))
	var exported := _files(FOLDER)
	SaveSlots.save_into(goya, 7, "Later")
	var other := _saved("Inniscor")
	var others := {}
	for file_name: String in _files(FOLDER):
		if file_name.begins_with(other.adventure_id):
			others[file_name] = FileAccess.get_file_as_bytes(FOLDER.path_join(file_name))
	assert_true(bool(AdventureTransfer.install(AdventureTransfer.take_in(zip))["ok"]))
	var now := _files(FOLDER)
	for file_name: String in others:
		assert_eq(now.get(file_name), others[file_name], "another adventure untouched")
		now.erase(file_name)
	assert_eq(now, exported, "the adventure exactly as it was exported")


# ------------------------------------------------------------- refusals --

func test_a_file_that_is_no_zip_or_has_no_manifest_is_refused() -> void:
	var text := OUT.path_join("notes.zip")
	var file := FileAccess.open(text, FileAccess.WRITE)
	file.store_string("just some words, no zip at all")
	file.close()
	_refused(text, AdventureTransfer.NOT_EXPORTED)
	var bare := OUT.path_join("bare.zip")
	_zip(bare, null, {"Goya-00000000.autosave.json": PackedByteArray([1, 2, 3])})
	_refused(bare, AdventureTransfer.NOT_EXPORTED)


func test_a_manifest_of_another_format_is_refused() -> void:
	var goya := _saved()
	var members := {goya.save_path().get_file(): FileAccess.get_file_as_bytes(goya.save_path())}
	var manifest := _manifest(goya.adventure_id, members)
	manifest["format"] = "something-else"
	var zip := OUT.path_join("wrong.zip")
	_zip(zip, manifest, members)
	_refused(zip, AdventureTransfer.NOT_EXPORTED)
	var broken := OUT.path_join("broken.zip")
	_zip(broken, "{ not json".to_utf8_buffer(), members)
	_refused(broken, AdventureTransfer.NOT_EXPORTED)


func test_a_member_with_a_path_is_refused() -> void:
	var goya := _saved()
	var bytes := FileAccess.get_file_as_bytes(goya.save_path())
	for name in ["sub/" + goya.save_path().get_file(), "../" + goya.save_path().get_file(),
			goya.adventure_id + ".notes.txt"]:
		var members := {name: bytes}
		var zip := OUT.path_join("path.zip")
		_zip(zip, _manifest(goya.adventure_id, members), members)
		_refused(zip, AdventureTransfer.MIXED)
		DirAccess.remove_absolute(zip)


func test_two_adventures_in_one_zip_are_refused() -> void:
	var goya := _saved()
	var other := _saved("Inniscor")
	var members := {goya.save_path().get_file(): FileAccess.get_file_as_bytes(goya.save_path()),
		other.save_path().get_file(): FileAccess.get_file_as_bytes(other.save_path())}
	var zip := OUT.path_join("two.zip")
	_zip(zip, _manifest(goya.adventure_id, members), members)
	_refused(zip, AdventureTransfer.MIXED)
	# Another adventure's save under this one's name.
	var swapped := {goya.save_path().get_file(): FileAccess.get_file_as_bytes(other.save_path())}
	var zip2 := OUT.path_join("swapped.zip")
	_zip(zip2, _manifest(goya.adventure_id, swapped), swapped)
	_refused(zip2, AdventureTransfer.MIXED)


func test_a_member_the_manifest_does_not_list_is_refused() -> void:
	var goya := _saved()
	var members := {goya.save_path().get_file(): FileAccess.get_file_as_bytes(goya.save_path())}
	var manifest := _manifest(goya.adventure_id, members)
	members[goya.save_path(SaveSlots.QUICK_KIND).get_file()] = FileAccess.get_file_as_bytes(
		goya.save_path(SaveSlots.QUICK_KIND))
	var zip := OUT.path_join("unlisted.zip")
	_zip(zip, manifest, members)
	_refused(zip, AdventureTransfer.MIXED)


func test_a_hash_that_does_not_match_is_refused() -> void:
	var goya := _saved()
	var name := goya.save_path().get_file()
	var members := {name: FileAccess.get_file_as_bytes(goya.save_path())}
	var manifest := _manifest(goya.adventure_id, members)
	var changed := (members[name] as PackedByteArray).duplicate()
	changed[changed.size() - 2] = changed[changed.size() - 2] ^ 1
	members[name] = changed
	var zip := OUT.path_join("hash.zip")
	_zip(zip, manifest, members)
	var read := AdventureTransfer.read_package(zip, "x.zip")
	assert_false(bool(read["ok"]))
	assert_eq(String(read["message"]), AdventureTransfer.DAMAGED % ["x.zip", name])


func test_a_save_that_is_not_json_is_refused() -> void:
	var goya := _saved()
	var name := goya.save_path().get_file()
	var members := {name: "{ cut sho".to_utf8_buffer()}
	var zip := OUT.path_join("cut.zip")
	_zip(zip, _manifest(goya.adventure_id, members), members)
	var read := AdventureTransfer.read_package(zip, "x.zip")
	assert_false(bool(read["ok"]))
	assert_eq(String(read["message"]), AdventureTransfer.UNREADABLE % ["x.zip", name])


func test_a_newer_save_format_or_export_format_is_refused_as_newer() -> void:
	var goya := _saved()
	var name := goya.save_path().get_file()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(goya.save_path()))
	data["version"] = AdventurePlayer.FORMAT_VERSION + 1
	var members := {name: JSON.stringify(data, "\t").to_utf8_buffer()}
	var zip := OUT.path_join("newer.zip")
	_zip(zip, _manifest(goya.adventure_id, members), members)
	_refused(zip, AdventureTransfer.NEWER)
	assert_string_contains(AdventureTransfer.NEWER, "saved by a newer version of the game",
		"the lists' own words")
	var plain := {name: FileAccess.get_file_as_bytes(goya.save_path())}
	var manifest := _manifest(goya.adventure_id, plain)
	manifest["version"] = AdventureTransfer.FORMAT_VERSION + 1
	var zip2 := OUT.path_join("newer_export.zip")
	_zip(zip2, manifest, plain)
	_refused(zip2, AdventureTransfer.NEWER)


func test_a_zip_too_big_is_refused() -> void:
	var goya := _saved()
	var zip := OUT.path_join("Goya.zip")
	assert_true(bool(AdventureTransfer.export_to(goya.adventure_id, zip)["ok"]))
	AdventureTransfer.max_total_bytes = 4096
	_refused(zip, AdventureTransfer.TOO_BIG)
	var package := AdventureTransfer.take_in(zip, "x.zip")
	assert_eq(String(package["message"]), AdventureTransfer.TOO_BIG % "x.zip", "refused before it is copied")
	assert_false(bool(AdventureTransfer.export_to(goya.adventure_id, OUT.path_join("again.zip"))["ok"]),
		"nor packed past the bound")


func test_a_refused_zip_writes_nothing() -> void:
	var goya := _saved()
	var before := _files(FOLDER)
	var name := goya.save_path().get_file()
	var members := {name: "{ cut sho".to_utf8_buffer()}
	var zip := OUT.path_join("cut.zip")
	_zip(zip, _manifest(goya.adventure_id, members), members)
	var package := AdventureTransfer.take_in(zip)
	assert_false(bool(package["ok"]))
	assert_false(bool(AdventureTransfer.install(package)["ok"]), "a refusal installs nothing")
	assert_eq(_files(FOLDER), before)
	assert_false(FileAccess.file_exists(AdventureTransfer.INCOMING))
