extends GutTest
## THE 0.60.19 BUG PASS OVER EXPORT AND IMPORT (h9-2, h9-3, h9-6, h9-7):
## [AdventureTransfer] reads a manifest or a save whose words are null
## without a script error, and refuses or takes it as the lists would; a
## zip cut short is "damaged or incomplete", never "bigger than an
## exported adventure can be"; a save the list shows from its `.bak` is
## exported and imported like any other; and the lists read a folder they
## are given.

const FOLDER := "user://urza_bugpass_x6_saves"
const OUT := "user://urza_bugpass_x6_out"
const HALL := "user://urza_bugpass_x6_hall"

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


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


## A zip at [param path] of [param manifest] and [param members]
## `{name: bytes}`.
func _zip(path: String, manifest: Variant, members: Dictionary) -> void:
	var packer := ZIPPacker.new()
	assert_eq(packer.open(path), OK)
	if manifest != null:
		packer.start_file(AdventureTransfer.MANIFEST)
		packer.write_file(JSON.stringify(manifest).to_utf8_buffer())
		packer.close_file()
	for name: String in members:
		packer.start_file(name)
		packer.write_file(members[name])
		packer.close_file()
	packer.close()


func _manifest(id: String, members: Dictionary) -> Dictionary:
	var rows: Array = []
	for name: String in members:
		var bytes: PackedByteArray = members[name]
		rows.append({"name": name, "bytes": bytes.size(), "sha256": AdventureTransfer.sha256(bytes)})
	return {"format": AdventureTransfer.FORMAT, "version": AdventureTransfer.FORMAT_VERSION,
		"adventure_id": id, "hero": "Goya", "files": rows}


## The autosave of [param adventure] as a record.
func _saved_record(adventure: AdventurePlayer) -> Dictionary:
	var path := FOLDER.path_join(adventure.save_path().get_file())
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# ------------------------------------------------- h9-2: null words read --

func test_a_manifest_whose_words_are_null_is_refused_as_no_export() -> void:
	# String(null) stopped the read with a script error: Import did nothing
	# at all and the note said nothing.
	var cases := [
		{"format": null, "version": null, "adventure_id": null, "files": null},
		{"format": AdventureTransfer.FORMAT, "version": 1, "adventure_id": null, "files": []},
		{"format": AdventureTransfer.FORMAT, "version": null, "adventure_id": "Goya-00000000", "files": []},
	]
	for i in cases.size():
		var zip := OUT.path_join("n%d.zip" % i)
		_zip(zip, cases[i], {})
		var read := AdventureTransfer.read_package(zip, "x.zip")
		assert_false(bool(read["ok"]), str(cases[i]))
		assert_eq(String(read["message"]), AdventureTransfer.NOT_EXPORTED % "x.zip", str(cases[i]))


func test_a_save_whose_hero_and_time_are_null_goes_out_and_comes_back() -> void:
	# The lists read such a save with an empty name and time
	# ([method AdventurePlayer.scan_saves]); Export and Import do too.
	var goya := _saved()
	var id := goya.adventure_id
	var data := _saved_record(goya)
	for file_name in DirAccess.get_files_at(FOLDER):
		DirAccess.remove_absolute(FOLDER.path_join(file_name))
	data["hero"]["name"] = null
	data["adventure"]["saved"] = null
	var name := goya.save_path().get_file()
	var bytes := JSON.stringify(data).to_utf8_buffer()
	_write(FOLDER.path_join(name), bytes)
	AdventurePlayer.forget_saves()
	assert_eq(AdventurePlayer.list_saves().size(), 1, "the list reads it")
	var made := AdventureTransfer.pack(id, OUT.path_join("made.zip"), [FOLDER])
	assert_true(bool(made["ok"]), String(made["message"]))
	assert_eq(int(made["saves"]), 1)
	assert_eq(String(made["hero"]), "")
	# A hand-made zip of it whose manifest's One-life mark is null.
	var members := {name: bytes}
	var manifest := _manifest(id, members)
	manifest["one_life"] = null
	var zip := OUT.path_join("n.zip")
	_zip(zip, manifest, members)
	var read := AdventureTransfer.read_package(zip, "n.zip")
	assert_true(bool(read["ok"]), String(read["message"]))
	assert_eq(int(read["saves"]), 1)
	assert_eq(String(read["hero"]), "")
	assert_eq(String(read["newest"]), "")
	assert_eq(String(read["one_life"]), "", "a null mark is no mark")


func test_a_save_whose_id_is_null_is_another_adventures() -> void:
	var goya := _saved()
	var id := goya.adventure_id
	var data := _saved_record(goya)
	data["adventure"]["id"] = null
	var name := goya.save_path().get_file()
	var members := {name: JSON.stringify(data).to_utf8_buffer()}
	var zip := OUT.path_join("n.zip")
	_zip(zip, _manifest(id, members), members)
	var read := AdventureTransfer.read_package(zip, "n.zip")
	assert_false(bool(read["ok"]))
	assert_eq(String(read["message"]), AdventureTransfer.MIXED % "n.zip")
	# Export leaves such a file out, and counts it.
	_write(FOLDER.path_join(name), members[name])
	var made := AdventureTransfer.pack(id, OUT.path_join("made.zip"), [FOLDER])
	assert_true(bool(made["ok"]), String(made["message"]))
	assert_eq(int(made["left_out"]), 1)


# ------------------------------------------- h9-3: a zip that was cut short --

func test_an_export_cut_short_is_damaged_or_incomplete() -> void:
	var goya := _saved()
	var whole := OUT.path_join("whole.zip")
	assert_true(bool(AdventureTransfer.pack(goya.adventure_id, whole, [FOLDER])["ok"]))
	var bytes := FileAccess.get_file_as_bytes(whole)
	for keep in [bytes.size() / 2, bytes.size() - 10, 12]:
		var cut := OUT.path_join("cut.zip")
		_write(cut, bytes.slice(0, keep))
		var read := AdventureTransfer.read_package(cut, "cut.zip")
		assert_false(bool(read["ok"]), "cut at %d" % keep)
		assert_eq(String(read["message"]), "cut.zip is damaged or incomplete: it may not have been copied whole.",
			"cut at %d" % keep)
		var taken := AdventureTransfer.take_in(cut, "cut.zip")
		assert_eq(String(taken["message"]), String(read["message"]), "and through Import")


func test_a_whole_zip_past_the_bounds_is_still_too_big() -> void:
	# More members than an export can have.
	var many := {}
	for i in AdventureTransfer.MAX_ENTRIES + 1:
		many["m%02d.json" % i] = "{}".to_utf8_buffer()
	var crowded := OUT.path_join("crowded.zip")
	_zip(crowded, {"format": AdventureTransfer.FORMAT}, many)
	assert_eq(String(AdventureTransfer.read_package(crowded, "x.zip")["message"]),
		AdventureTransfer.TOO_BIG % "x.zip", "too many members")
	# A small zip that unpacks past the bound.
	var big := PackedByteArray()
	big.resize(64 * 1024)
	var packed := OUT.path_join("packed.zip")
	_zip(packed, {"format": AdventureTransfer.FORMAT}, {"a.json": big, "b.json": big})
	var length := FileAccess.get_file_as_bytes(packed).size()
	AdventureTransfer.max_total_bytes = 32 * 1024
	assert_lt(length, AdventureTransfer.max_total_bytes, "the zip itself is within the bound")
	assert_eq(String(AdventureTransfer.read_package(packed, "x.zip")["message"]),
		AdventureTransfer.TOO_BIG % "x.zip", "what it unpacks to is not")


func test_a_file_that_is_no_zip_is_still_no_export() -> void:
	var junk := OUT.path_join("junk.zip")
	_write(junk, "not a zip at all, but long enough to be looked at".to_utf8_buffer())
	assert_eq(String(AdventureTransfer.read_package(junk, "x.zip")["message"]),
		AdventureTransfer.NOT_EXPORTED % "x.zip")


# ---------------------------------------- h9-6: a save shown from its .bak --

func test_saves_the_list_shows_from_their_bak_are_exported_and_imported() -> void:
	var goya := _saved()
	var id := goya.adventure_id
	for kind in [AdventurePlayer.AUTOSAVE, SaveSlots.QUICK_KIND, SaveSlots.kind(2)]:
		_write(FOLDER.path_join("%s.%s.json" % [id, kind]), "{broken".to_utf8_buffer())
	AdventurePlayer.forget_saves()
	assert_eq(AdventurePlayer.list_saves().size(), 3, "the list shows three saves, from their .bak copies")
	var zip := OUT.path_join("bak.zip")
	var made := AdventureTransfer.pack(id, zip, [FOLDER])
	assert_true(bool(made["ok"]), String(made["message"]))
	assert_eq(int(made["saves"]), 3, "each counted once")
	assert_eq(int(made["left_out"]), 3, "the damaged files left out")
	assert_eq(String(made["hero"]), "Goya")
	var read := AdventureTransfer.read_package(zip, "bak.zip")
	assert_true(bool(read["ok"]), String(read["message"]))
	assert_eq(int(read["saves"]), 3)
	assert_eq(String(read["hero"]), "Goya")
	assert_ne(String(read["newest"]), "")
	_wipe(FOLDER)
	DirAccess.make_dir_recursive_absolute(FOLDER)
	AdventurePlayer.forget_saves()
	var done := AdventureTransfer.install(read, [FOLDER])
	assert_true(bool(done["ok"]), String(done["message"]))
	assert_eq(String(done["message"]), AdventureTransfer.imported_words("Goya", 3))
	AdventurePlayer.forget_saves()
	assert_eq(AdventurePlayer.list_saves().size(), 3, "and listed on the other device")


func test_a_save_and_its_bak_count_once() -> void:
	var goya := _saved()
	var zip := OUT.path_join("both.zip")
	var made := AdventureTransfer.pack(goya.adventure_id, zip, [FOLDER])
	assert_eq(int(made["saves"]), 3)
	assert_eq(int(AdventureTransfer.read_package(zip)["saves"]), 3)


func test_a_bak_without_its_save_is_here_already() -> void:
	# The Replace question counts what the list shows.
	var goya := _saved()
	DirAccess.remove_absolute(FOLDER.path_join(goya.save_path().get_file()))
	AdventurePlayer.forget_saves()
	assert_eq(AdventurePlayer.list_saves().size(), 3)
	var here := AdventureTransfer.existing(goya.adventure_id)
	assert_eq(int(here["files"]), 5)
	assert_eq(int(here["saves"]), 3, "the autosave read from its .bak counts")


# ------------------------------------------- h9-7: the lists of one folder --

func test_the_lists_read_the_folder_they_are_given() -> void:
	_saved()
	var scanned := AdventurePlayer.scan_saves(FOLDER)
	assert_eq((scanned["saves"] as Array).size(), 3)
	assert_eq(int(scanned["unreadable"]), 0)
	assert_eq(AdventurePlayer.list_saves(FOLDER).size(), 3)
	assert_eq(AdventurePlayer.list_saves(OUT).size(), 0, "a folder of no saves")
