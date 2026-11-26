extends GutTest
## Campaign 2026-11-26, smooth1 #7: Magic Battle parsed every deck file at
## each opening (65-70 ms for the 330 shipped decks). A file read the same
## as last time is not parsed again; a file that changed, a new one and a
## changed card pool are.

const SETUP := preload("res://game/setup_screen.gd")
const NAME := "c1126_deck_scan_probe"

var _path := ""


func before_each() -> void:
	CardRegistry.ensure_loaded()
	DirAccess.make_dir_recursive_absolute(DeckStore.USER_DIR)
	_path = "%s/%s.deck" % [DeckStore.USER_DIR, NAME]
	_write("name: Scan Probe\n40 Mountain\n20 Lightning Bolt\n")
	SETUP._scan_kept.clear()


func after_each() -> void:
	DirAccess.remove_absolute(_path)
	SETUP._scan_kept.clear()


func _write(text: String) -> void:
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _open() -> Node:
	var screen: Node = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(screen)
	return screen


func _lists(screen: Node) -> Array:
	return [screen._deck_paths.duplicate(), screen._playable_paths.duplicate(), screen._deck_titles.duplicate(),
		screen._deck_masks.duplicate(), screen._proxy_paths.duplicate(true), screen._pack_paths.duplicate(true),
		screen._scan_groups.duplicate(), screen._playable_lists.duplicate(true)]


func test_a_second_opening_parses_nothing_and_lists_the_same() -> void:
	var first := _open()
	await get_tree().process_frame
	var listed := _lists(first)
	assert_true(first._playable_paths.has(_path), "the probe deck is listed")
	assert_eq(String(first._deck_titles[_path]), "Scan Probe")
	var kept: Dictionary = SETUP._scan_kept.duplicate()
	assert_eq(kept.size(), DeckStore.all_deck_paths().size(), "every file is kept")
	var second := _open()
	await get_tree().process_frame
	assert_eq(_lists(second), listed, "the same lists")
	var same := 0
	for path in kept:
		if is_same(kept[path][2], SETUP._scan_kept[path][2]):
			same += 1
	assert_eq(same, kept.size(), "no file was parsed again")
	# A fresh parse of everything agrees with what was kept.
	SETUP._scan_kept.clear()
	var third := _open()
	await get_tree().process_frame
	assert_eq(_lists(third), listed)


func test_a_changed_file_is_read_anew_and_a_deleted_one_is_let_go() -> void:
	var first := _open()
	await get_tree().process_frame
	var old: DeckList = SETUP._scan_kept[_path][2]
	# The same length and, within a second, the same clock: only the text tells.
	_write("name: Scan Other\n40 Mountain\n20 Lightning Bolt\n")
	var second := _open()
	await get_tree().process_frame
	assert_eq(String(second._deck_titles[_path]), "Scan Other")
	assert_false(is_same(old, SETUP._scan_kept[_path][2]), "parsed again")
	_write("name: Scan Other\n40 Mountain\n20 Zzz No Such Card\n")
	var third := _open()
	await get_tree().process_frame
	assert_false(third._playable_paths.has(_path), "a proxy deck is not playable")
	assert_true(third._proxy_paths.has(_path))
	DirAccess.remove_absolute(_path)
	var fourth := _open()
	await get_tree().process_frame
	assert_false(fourth._deck_paths.has(_path))
	assert_false(SETUP._scan_kept.has(_path), "let go with its file")


func test_a_changed_pool_lets_the_table_go() -> void:
	_open()
	await get_tree().process_frame
	var old: DeckList = SETUP._scan_kept[_path][2]
	CardRegistry.revision += 1
	_open()
	await get_tree().process_frame
	assert_false(is_same(old, SETUP._scan_kept[_path][2]), "the pool moved: parsed again")
	CardRegistry.revision -= 1
