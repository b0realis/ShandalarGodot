extends GutTest
## THE 0.60.19 BUG PASS, h9-1: ON A DEVICE WITH NO ADVENTURE SAVED, SAVE /
## LOAD STILL REACHES IMPORT. The title's Save / Load said "No adventure
## has been saved yet" in a popup with only OK, so the Import beside the
## list (2026-11-06) could not be reached on the very device an adventure
## is brought to — where the guide says to press it. Save / Load now always
## opens the list; with nothing saved its note says how a save comes to be
## and that Import brings one in.

const SAVES := "user://urza_bugpass_x6_menu_saves"


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	DirAccess.make_dir_recursive_absolute(SAVES)
	AdventurePlayer.forget_saves()


func after_each() -> void:
	var opened := get_tree().current_scene
	if opened != null:
		opened.free()
		get_tree().current_scene = null
	for file_name in DirAccess.get_files_at(SAVES):
		DirAccess.remove_absolute(SAVES.path_join(file_name))
	DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	AdventurePlayer.forget_saves()


func _menu_entry(title: Control, text: String) -> Button:
	for n in title.find_children("*", "Button", true, false):
		if (n as Button).text == text:
			return n
	return null


func test_save_load_with_nothing_saved_opens_the_list_with_import() -> void:
	assert_null(get_tree().current_scene, "the runner has no current scene to replace")
	var title: Control = load("res://game/main.tscn").instantiate()
	add_child_autofree(title)
	await get_tree().process_frame
	assert_true(AdventurePlayer.list_saves().is_empty(), "no adventure on this device yet")
	var save_load := _menu_entry(title, "Save / Load")
	assert_not_null(save_load)
	save_load.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(UiChrome.open_popup(title), "no popup with only OK over the title")
	var opened := get_tree().current_scene
	assert_not_null(opened, "the list opened")
	if opened == null:
		return
	assert_eq(opened.scene_file_path, "res://game/adventure/load_adventure_screen.tscn")
	var list := opened as LoadAdventureScreen
	assert_false(list.import_button.disabled, "Import is there to press")
	assert_true(list.resume_button.disabled, "nothing to resume")
	assert_true(list.export_button.disabled, "nothing to export")
	var note := (list.find_child("Note", true, false) as Label).text
	assert_string_contains(note, "No adventure has been saved yet")
	assert_string_contains(note, "Import brings in an adventure exported on another device")
