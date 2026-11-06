extends GutTest
## THE SAVES WHERE A PLAYER CAN REACH THEM ON ANDROID (a player on Android,
## and the owner, 2026-11-06): there `user://` is the app's private folder,
## which only root can open, so the saves live in the app's corner of the
## shared storage, `<files>/adventures/`, beside the card packs ([method
## AdventurePlayer.saves_place]). Saves already in `user://adventures`
## move there once, each copied whole, read back byte for byte and only
## then removed; one that does not is left, and both folders are read
## until it moves ([method AdventurePlayer.move_saves]). Off Android
## nothing changes. Android itself is stood in for by [member
## AdventurePlayer.android_dir].

const ROOT := "user://adventure_tests_android"
const PRIVATE := ROOT + "/private_adventures"
const FILES := ROOT + "/files"

var _android_dir := ""
var _saves_folder := ""
var _saves_left := ""
var _settled := false


func before_each() -> void:
	_android_dir = AdventurePlayer.android_dir
	_saves_folder = AdventurePlayer.saves_folder
	_saves_left = AdventurePlayer.saves_left
	_settled = AdventurePlayer._settled
	_wipe(ROOT)
	DirAccess.make_dir_recursive_absolute(PRIVATE)
	DirAccess.make_dir_recursive_absolute(FILES)
	AdventurePlayer.forget_saves()


func after_each() -> void:
	AdventurePlayer.android_dir = _android_dir
	AdventurePlayer.saves_folder = _saves_folder
	AdventurePlayer.saves_left = _saves_left
	AdventurePlayer._settled = _settled
	_wipe(ROOT)
	AdventurePlayer.forget_saves()


func _wipe(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file_name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))
	for sub in DirAccess.get_directories_at(folder):
		_wipe(folder.path_join(sub))
	DirAccess.remove_absolute(folder)


## An adventure of [param hero] saved into [param folder]: its autosave
## twice (so it keeps a `.bak`) and slot 1.
func _saved_in(folder: String, hero := "Goya") -> AdventurePlayer:
	AdventurePlayer.saves_folder = folder
	var setup := AdventureSetup.new()
	setup.player_name = hero
	setup.color = "green"
	setup.difficulty = 0
	setup.walker = "female"
	setup.seed_text = "99"
	var record := setup.resolve({})
	var adventure := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	adventure.autosave()
	adventure.autosave()
	SaveSlots.save_into(adventure, 1, "Before the castle")
	return adventure


func _files(folder: String) -> Dictionary:
	var out := {}
	if DirAccess.dir_exists_absolute(folder):
		for file_name in DirAccess.get_files_at(folder):
			out[file_name] = FileAccess.get_file_as_bytes(folder.path_join(file_name))
	return out


## The shared corner's saves folder, and Android stood in for.
func _on_android() -> String:
	AdventurePlayer.android_dir = FILES
	var shared := AdventurePlayer.saves_place(FILES)
	AdventurePlayer.saves_folder = shared
	AdventurePlayer.saves_left = ""
	AdventurePlayer._settled = false
	return shared


func test_the_saves_folder_is_the_shared_corner_on_android_only() -> void:
	assert_eq(AdventurePlayer.saves_place(""), "user://adventures", "a desktop and a browser: as always")
	assert_eq(AdventurePlayer.saves_place("/storage/emulated/0/Android/data/com.b0realis.shandalar.android/files"),
		"/storage/emulated/0/Android/data/com.b0realis.shandalar.android/files/adventures")
	assert_eq(AdventurePlayer.saves_place("/sdcard/Android/data/com.b0realis.shandalar/files/"),
		"/sdcard/Android/data/com.b0realis.shandalar/files/adventures", "a trailing slash is one folder")
	assert_eq(AdventurePlayer.SAVES_FOLDER, "user://adventures")
	if not OS.has_feature("android"):
		assert_eq(AdventurePlayer.android_dir, "", "no corner off Android")
		assert_eq(AdventurePlayer.saves_place(AdventurePlayer.android_dir), AdventurePlayer.SAVES_FOLDER,
			"so the saves stay where they always were")


func test_off_android_nothing_moves() -> void:
	var goya := _saved_in(PRIVATE)
	var before := _files(PRIVATE)
	AdventurePlayer.android_dir = ""
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	AdventurePlayer.saves_left = ""
	AdventurePlayer._settled = false
	AdventurePlayer.settle_saves(PRIVATE)
	assert_eq(_files(PRIVATE), before, "every file where it was")
	assert_eq(AdventurePlayer.saves_left, "")
	assert_eq(AdventurePlayer.saves_folders(), [AdventurePlayer.SAVES_FOLDER] as Array[String])
	assert_ne(goya.adventure_id, "")


func test_a_test_folder_is_never_moved_into() -> void:
	_saved_in(PRIVATE)
	var before := _files(PRIVATE)
	AdventurePlayer.android_dir = FILES
	AdventurePlayer.saves_folder = ROOT + "/a_test_of_its_own"
	AdventurePlayer._settled = false
	AdventurePlayer.settle_saves(PRIVATE)
	assert_eq(_files(PRIVATE), before, "only the corner's own folder is moved into")


func test_on_android_the_saves_move_once_byte_for_byte() -> void:
	var goya := _saved_in(PRIVATE)
	var before := _files(PRIVATE)
	assert_eq(before.size(), 3, "autosave, its .bak, slot 1")
	var shared := _on_android()
	AdventurePlayer.settle_saves(PRIVATE)
	assert_eq(_files(shared), before, "each file whole in the shared corner")
	assert_eq(_files(PRIVATE), {}, "and gone from the private folder")
	assert_eq(AdventurePlayer.saves_left, "", "nothing left behind")
	assert_eq(AdventurePlayer.saves_folders(), [shared] as Array[String])
	var listed := AdventurePlayer.list_saves()
	assert_eq(listed.size(), 2, "the autosave and slot 1 listed")
	for save in listed:
		assert_true(String(save["path"]).begins_with(shared))
	var back := AdventurePlayer.load_from(shared.path_join(goya.save_path().get_file()))
	assert_not_null(back, "and it loads from there")
	# Once a run: a save put back by hand is not looked for again.
	var stray := PRIVATE.path_join(goya.save_path().get_file())
	var file := FileAccess.open(stray, FileAccess.WRITE)
	file.store_buffer(before[goya.save_path().get_file()])
	file.close()
	AdventurePlayer.settle_saves(PRIVATE)
	assert_true(FileAccess.file_exists(stray), "the move runs once a run")


func test_a_save_that_cannot_be_written_stays_and_both_folders_are_read() -> void:
	var goya := _saved_in(PRIVATE)
	var other := _saved_in(PRIVATE, "Inniscor")
	var shared := _on_android()
	# Slot 1's place in the corner is taken by a folder: its copy cannot land.
	var slot := goya.save_path(SaveSlots.kind(1)).get_file()
	DirAccess.make_dir_recursive_absolute(shared.path_join(slot))
	var result := AdventurePlayer.move_saves(PRIVATE, shared)
	assert_eq(int(result["left"]), 1)
	assert_true(FileAccess.file_exists(PRIVATE.path_join(slot)), "the save is left where it was")
	assert_eq(AdventurePlayer.saves_left, PRIVATE, "and its folder is read meanwhile")
	AdventurePlayer._settled = true
	assert_eq(AdventurePlayer.saves_folders(), [shared, PRIVATE] as Array[String])
	var listed := AdventurePlayer.list_saves()
	var paths := listed.map(func(s: Dictionary) -> String: return String(s["path"]))
	assert_has(paths, PRIVATE.path_join(slot), "the save left behind is listed")
	assert_has(paths, shared.path_join(goya.save_path().get_file()), "beside the ones that moved")
	assert_eq(listed.size(), 4, "both adventures whole: two autosaves, two slots")
	# The next run, the way clear, it moves.
	DirAccess.remove_absolute(shared.path_join(slot))
	AdventurePlayer._settled = false
	AdventurePlayer.settle_saves(PRIVATE)
	assert_false(FileAccess.file_exists(PRIVATE.path_join(slot)))
	assert_true(FileAccess.file_exists(shared.path_join(slot)))
	assert_eq(AdventurePlayer.saves_left, "")
	assert_ne(other.adventure_id, goya.adventure_id)


func test_a_save_written_meanwhile_in_the_corner_is_never_written_over() -> void:
	var goya := _saved_in(PRIVATE)
	var name := goya.save_path().get_file()
	var old := FileAccess.get_file_as_bytes(PRIVATE.path_join(name))
	var shared := _on_android()
	# The game saved the adventure in the corner meanwhile: newer bytes.
	goya.gold = 999
	assert_ne(goya.save(shared.path_join(name)), "")
	var newer := FileAccess.get_file_as_bytes(shared.path_join(name))
	AdventurePlayer.move_saves(PRIVATE, shared)
	assert_eq(FileAccess.get_file_as_bytes(shared.path_join(name)), newer, "the newer save kept")
	assert_eq(FileAccess.get_file_as_bytes(PRIVATE.path_join(name)), old, "the older one left, not lost")
	AdventurePlayer._settled = true
	var shown := AdventurePlayer.list_saves().filter(func(s: Dictionary) -> bool:
		return int(s["slot"]) == 0)
	assert_eq(shown.size(), 1, "one autosave shown for the adventure")
	assert_eq(int(shown[0]["gold"]), 999, "the newer one")


func test_a_copy_already_in_the_corner_lets_the_old_file_go() -> void:
	var goya := _saved_in(PRIVATE)
	var name := goya.save_path().get_file()
	var shared := _on_android()
	DirAccess.make_dir_recursive_absolute(shared)
	DirAccess.copy_absolute(PRIVATE.path_join(name), shared.path_join(name))
	AdventurePlayer.move_saves(PRIVATE, shared)
	assert_false(FileAccess.file_exists(PRIVATE.path_join(name)), "the same bytes are there already")
	assert_eq(AdventurePlayer.saves_left, "")


func test_deleting_a_save_left_behind_deletes_both_copies() -> void:
	var goya := _saved_in(PRIVATE)
	var name := goya.save_path().get_file()
	var shared := _on_android()
	goya.gold = 5
	goya.save(shared.path_join(name))
	AdventurePlayer.move_saves(PRIVATE, shared)
	AdventurePlayer._settled = true
	assert_eq(AdventurePlayer.saves_left, PRIVATE, "the older autosave left behind")
	var list: LoadAdventureScreen = load("res://game/adventure/load_adventure_screen.tscn").instantiate()
	add_child_autofree(list)
	await get_tree().process_frame
	var autosave := {}
	for save in list.saves:
		if int(save["slot"]) == 0:
			autosave = save
	assert_false(autosave.is_empty())
	list.delete_save(autosave)
	assert_false(FileAccess.file_exists(shared.path_join(name)), "the copy shown gone")
	assert_false(FileAccess.file_exists(PRIVATE.path_join(name)), "and the one behind it, which would show next")
	for save in list.saves:
		assert_ne(int(save["slot"]), 0, "no autosave listed")
