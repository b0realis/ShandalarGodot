extends GutTest
## OPTIONS › CARD PACKS › `Add pack...` (2026-10-21).
##
## The review of 2026-10-21 found the Android guide promising an in-game
## way to add a numbered pack that did not exist (nettools-1); the guide
## was corrected to adb, and the owner chose from three mockups an
## `Add pack...` beside Open Folder and Rescan: *"Yes A is the leanest"*.
## A phone's pack folder lies under Android/data, which Open Folder cannot
## open; now a zip chosen anywhere is recognised by what it holds, checked
## by its own pack's contract, and only then copied in under its exact
## name ([method CardPacks.install_pack]) — so a renamed download is taken
## and a wrong one never replaces a pack that works.
##
## Every pack here is the runner's metadata-only build
## (`SHANDALAR_PACK_N`), copied into a scratch folder; the real pack
## folder is never written.

const SCRATCH := "user://test_card_packs_add_pack"
const FUTURE := "99.0.0"


func before_each() -> void:
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH).path_join("folder"))


func after_each() -> void:
	_wipe(ProjectSettings.globalize_path(SCRATCH))


func _wipe(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(name))
	for name in DirAccess.get_directories_at(path):
		_wipe(path.path_join(name))
	DirAccess.remove_absolute(path)


func _folder() -> String:
	return ProjectSettings.globalize_path(SCRATCH).path_join("folder")


## The runner's Pack 2, copied to [param name] in the scratch folder.
func _pack_2_as(name: String) -> String:
	var source := OS.get_environment("SHANDALAR_PACK_2")
	assert_true(FileAccess.file_exists(source), "the runner's metadata-only Pack 2")
	var path := ProjectSettings.globalize_path(SCRATCH).path_join(name)
	assert_eq(DirAccess.copy_absolute(source, path), OK)
	return path


func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)


func _staged_files() -> PackedStringArray:
	var staging := ProjectSettings.globalize_path(CardPacks.INCOMING)
	return DirAccess.get_files_at(staging) if DirAccess.dir_exists_absolute(staging) \
		else PackedStringArray()


# ================================================================ the page ==

func test_the_button_sits_beside_open_folder_and_rescan() -> void:
	var screen: Control = load("res://game/card_packs_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var add := screen.find_child("AddPack", true, false) as Button
	assert_not_null(add, "the page has the button")
	if add == null:
		return
	assert_eq(add.text, "Add pack...")
	var row: Array[String] = []
	for child in add.get_parent().get_children():
		row.append(String(child.name))
	assert_eq(row, ["OpenFolder", "Rescan", "AddPack"] as Array[String],
		"the top row, after Open Folder and Rescan (option A)")
	assert_false(add.disabled, "on every platform but the browser")
	var note := screen.find_child("AddPackNote", true, false) as Label
	assert_false(note.visible, "nothing to say before the first try")


func test_the_page_says_what_came_of_it() -> void:
	var screen: Control = load("res://game/card_packs_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var note := screen.find_child("AddPackNote", true, false) as Label
	CardPacks.pack_added.emit({"ok": false, "id": "", "message": "x.zip is not a numbered card pack (Pack-1 to Pack-9)."})
	assert_true(note.visible)
	assert_string_contains(note.text, "not a numbered card pack")


func test_a_locked_catalogue_adds_nothing() -> void:
	CardPacks.lock_catalogue(self)
	var result := CardPacks.add_pack(_pack_2_as("Pack-2-Fallen-Empires.zip"))
	CardPacks.unlock_catalogue(self)
	assert_false(bool(result.ok), "not while a LAN table holds the catalogue")
	assert_ne(String(result.message), "", "and it says why")


# ========================================================== which pack ==

func test_each_pack_is_known_by_what_it_holds() -> void:
	for number in range(1, 10):
		var source := OS.get_environment("SHANDALAR_PACK_%d" % number)
		if source == "" or not FileAccess.file_exists(source):
			fail_test("the runner built no Pack %d" % number)
			continue
		var renamed := ProjectSettings.globalize_path(SCRATCH).path_join("download (%d).zip" % number)
		DirAccess.copy_absolute(source, renamed)
		assert_eq(CardPacks.pack_in(renamed), CardPacks.known_ids()[number - 1],
			"Pack %d, whatever the file is called" % number)


# ============================================================== adding ==

func test_a_renamed_download_is_added_under_its_own_name() -> void:
	var source := _pack_2_as("Pack-2-Fallen-Empires (1).zip")
	var result := CardPacks.install_pack(source, _folder())
	assert_true(bool(result.ok), String(result.message))
	assert_eq(String(result.id), FallenEmpiresPack.ID)
	var kept := _folder().path_join(FallenEmpiresPack.FILE_NAME)
	assert_true(FileAccess.file_exists(kept), "kept under the name its contract asks")
	assert_eq(_bytes(kept), _bytes(source), "byte for byte")
	assert_string_contains(String(result.message), "Pack 2")
	assert_eq(_staged_files(), PackedStringArray(), "nothing left in the check folder")


func test_a_zip_that_is_no_pack_is_refused() -> void:
	var path := ProjectSettings.globalize_path(SCRATCH).path_join("my_skin.zip")
	var packer := ZIPPacker.new()
	assert_eq(packer.open(path), OK)
	packer.start_file("skin/readme.txt")
	packer.write_file("a skin".to_utf8_buffer())
	packer.close_file()
	packer.close()
	var result := CardPacks.install_pack(path, _folder())
	assert_false(bool(result.ok))
	assert_string_contains(String(result.message), "is not a numbered card pack")
	assert_eq(DirAccess.get_files_at(_folder()), PackedStringArray(), "the folder is untouched")


func test_a_file_that_is_no_zip_is_refused() -> void:
	var path := ProjectSettings.globalize_path(SCRATCH).path_join("Pack-9-Tempest-Block.zip")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not a zip at all")
	file.close()
	var result := CardPacks.install_pack(path, _folder())
	assert_false(bool(result.ok), "a name is not a pack")
	assert_eq(DirAccess.get_files_at(_folder()), PackedStringArray())


func test_a_pack_for_a_newer_game_never_replaces_the_one_that_works() -> void:
	var good := _pack_2_as("good.zip")
	var kept := _folder().path_join(FallenEmpiresPack.FILE_NAME)
	assert_eq(DirAccess.copy_absolute(good, kept), OK)
	var newer := _rebuilt_pack_2({"minimum_game_version": FUTURE}, "newer.zip")
	var result := CardPacks.install_pack(newer, _folder())
	assert_false(bool(result.ok))
	assert_string_contains(String(result.message), "requires game version " + FUTURE,
		"the pack's own reason")
	assert_eq(_bytes(kept), _bytes(good), "the pack that works is still there, whole")
	assert_eq(_staged_files(), PackedStringArray(), "and the refused copy is gone")


## The runner's Pack 2 with its manifest changed by [param tweak], written
## by Python's zipfile as the runner's packs are (ZIPPacker adds a folder
## entry no pack layout allows).
func _rebuilt_pack_2(tweak: Dictionary, name: String) -> String:
	var reader := ZIPReader.new()
	assert_eq(reader.open(OS.get_environment("SHANDALAR_PACK_2")), OK)
	var entries := {}
	for entry in reader.get_files():
		entries[entry] = reader.read_file(entry).get_string_from_utf8()
	reader.close()
	var manifest_name := FallenEmpiresPack.PREFIX + "manifest.json"
	var manifest: Dictionary = JSON.parse_string(entries[manifest_name])
	manifest.merge(tweak, true)
	entries[manifest_name] = JSON.stringify(manifest, "  ")
	var path := ProjectSettings.globalize_path(SCRATCH).path_join(name)
	var spec := path + ".json"
	var file := FileAccess.open(spec, FileAccess.WRITE)
	file.store_string(JSON.stringify(entries))
	file.close()
	var output := []
	var status := OS.execute("python3", ["-I", "-c",
		"import json, sys, zipfile\nentries = json.load(open(sys.argv[1], encoding='utf-8'))\nwith zipfile.ZipFile(sys.argv[2], 'w', zipfile.ZIP_DEFLATED) as z:\n    for name, text in entries.items():\n        z.writestr(name, text.encode('utf-8'))\n",
		spec, path], output, true)
	assert_eq(status, 0, "\n".join(PackedStringArray(output)))
	return path
