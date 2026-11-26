extends GameTest
## PAST GAMES: DELETE, DELETE ALL, AND THE BOUND SAID (campaign of
## 2026-11-26). The screen listed every recording and could remove none;
## the folder grew for good. Each delete is asked first, Cancel holding the
## focus, and both buttons are reached and pressed from the keyboard.

const FOLDER := "user://c1126_files_past"

var _paths: Array[String] = []


func before_each() -> void:
	super.before_each()
	_clear()
	DirAccess.make_dir_recursive_absolute(FOLDER)
	_paths.clear()
	var archives: Array[MpnArchive] = []
	for i in 3:
		var archive := MpnArchive.new()
		assert_true(archive.start(g, MpnArchive.metadata(g, "test"), FOLDER))
		archives.append(archive)
	g.concede(1)
	for archive in archives:
		archive.close()
	_paths = MpnArchive.files(FOLDER)
	assert_eq(_paths.size(), 3)


func after_each() -> void:
	_clear()


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(FOLDER):
		return
	for name in DirAccess.get_files_at(FOLDER):
		DirAccess.remove_absolute(FOLDER.path_join(name))
	DirAccess.remove_absolute(FOLDER)


func _screen() -> PastGamesScreen:
	var screen := PastGamesScreen.new()
	screen.archive_directory = FOLDER
	add_child_autofree(screen)
	return screen


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await get_tree().process_frame


func _texts(node: Node) -> String:
	var out := ""
	for label in node.find_children("*", "Label", true, false):
		out += (label as Label).text + "\n"
	return out


func test_the_screen_says_the_bound_and_delete_waits_for_a_recording() -> void:
	var screen := _screen()
	assert_string_contains(_texts(screen), "The newest 500 recordings are kept, up to 64 MB")
	assert_true(screen._delete.disabled, "nothing open, nothing to delete")
	assert_false(screen._delete_all.disabled)
	assert_eq(screen._delete.focus_mode, Control.FOCUS_ALL, "reached by the focus ring")
	assert_eq(screen._delete_all.focus_mode, Control.FOCUS_ALL)
	assert_true(screen.open_record(_paths[1]))
	assert_false(screen._delete.disabled)
	# A file opened from elsewhere is not this screen's to remove.
	var outside := "user://c1126_files_past_outside.mpn"
	DirAccess.copy_absolute(_paths[1], outside)
	assert_true(screen.open_record(outside))
	assert_true(screen._delete.disabled)
	assert_null(screen.ask_delete())
	DirAccess.remove_absolute(outside)


func test_delete_asks_first_and_cancel_holds_the_focus() -> void:
	var screen := _screen()
	assert_true(screen.open_record(_paths[1]))
	screen._delete.grab_focus()
	await _key(KEY_ENTER)
	var popup := UiChrome.open_popup(screen)
	assert_not_null(popup, "Enter on Delete asks")
	assert_string_contains(_texts(popup), screen._games.get_item_text(1) + " will be removed")
	var focused := get_viewport().gui_get_focus_owner()
	assert_eq(String(focused.name), "Cancel", "the safe answer holds the focus")
	await _key(KEY_ENTER)
	await get_tree().process_frame
	assert_true(FileAccess.file_exists(_paths[1]), "Cancel deletes nothing")
	assert_eq(screen.current_path, _paths[1])
	# Again, and across to Delete with the arrow.
	screen._delete.grab_focus()
	await _key(KEY_ENTER)
	await _key(KEY_RIGHT)
	assert_eq(String(get_viewport().gui_get_focus_owner().name), "Delete")
	await _key(KEY_ENTER)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(FileAccess.file_exists(_paths[1]), "the recording is gone")
	assert_true(FileAccess.file_exists(_paths[0]) and FileAccess.file_exists(_paths[2]), "the others stay")
	assert_eq(screen.current_path, "")
	assert_true(screen.document.is_empty())
	assert_eq(screen._games.item_count, 2)
	assert_true(screen._delete.disabled and screen._export.disabled and screen._watch.disabled and screen._moves.disabled)
	assert_eq(screen._notice.text, "The recording was deleted.")
	var now := get_viewport().gui_get_focus_owner()
	assert_not_null(now, "the focus is not lost with the button that went dark")
	assert_false(now is Button and (now as Button).disabled, str(now))


func test_delete_all_asks_first_and_empties_the_list() -> void:
	var screen := _screen()
	assert_true(screen.open_record(_paths[0]))
	var note := FOLDER.path_join("notes.txt")
	FileAccess.open(note, FileAccess.WRITE).store_string("mine")
	screen._delete_all.grab_focus()
	await _key(KEY_ENTER)
	var popup := UiChrome.open_popup(screen)
	assert_not_null(popup)
	assert_string_contains(_texts(popup), "All 3 of your recordings will be removed")
	await _key(KEY_ESCAPE)
	await get_tree().process_frame
	if UiChrome.open_popup(screen) != null:
		UiChrome.dismiss_popup(UiChrome.open_popup(screen))
		await get_tree().process_frame
	assert_eq(MpnArchive.files(FOLDER).size(), 3, "backing out deletes nothing")
	var asked := screen.ask_delete_all()
	(asked.find_child("DeleteAll", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(MpnArchive.files(FOLDER).size(), 0)
	assert_true(FileAccess.file_exists(note), "only recordings go")
	assert_eq(screen._notice.text, "3 recordings deleted.")
	assert_true(screen._delete_all.disabled and screen._delete.disabled)
	assert_eq(screen._games.get_item_text(0), "No games recorded yet")
	DirAccess.remove_absolute(note)
