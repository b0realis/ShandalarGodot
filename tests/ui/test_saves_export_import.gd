extends GutTest
## EXPORT AND IMPORT ON THE SAVED ADVENTURES (a player on Android asked
## whether he can copy his saves to a PC; the owner, 2026-11-06: *"Yes
## implement both point 1. And 2.!"*): Export writes the highlighted save's
## whole adventure as one zip; Import takes one in — asking Replace or
## Cancel when the adventure is here already — and the list highlights it
## ([LoadAdventureScreen], [AdventureTransfer]). The platform's file boxes
## are not opened here: the screen's own steps after them are, and the
## browser's page is stood in for.

const SAVES := "user://adventure_tests_export_import"
const OUT := "user://adventure_tests_export_import_out"

var viewport: SubViewport


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	_wipe(SAVES)
	_wipe(OUT)
	DirAccess.make_dir_recursive_absolute(OUT)
	AdventurePlayer.forget_saves()


func after_each() -> void:
	for node in get_tree().root.get_children():
		if node is WorldScreen:
			node.queue_free()
	await get_tree().process_frame
	_wipe(SAVES)
	_wipe(OUT)
	_wipe(AdventureTransfer.STAGING)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	AdventurePlayer.forget_saves()


func _wipe(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file_name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))
	DirAccess.remove_absolute(folder)


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


func _setup(hero := "Goya") -> AdventureSetup:
	var setup := AdventureSetup.new()
	setup.player_name = hero
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	return setup


## Adventure of [param hero] saved three ways, each with its `.bak`.
func _saved(hero := "Goya") -> AdventurePlayer:
	var record := _setup(hero).resolve({})
	var adventure := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	adventure.gold = 250
	for twice in 2:
		adventure.autosave()
		SaveSlots.save_quick(adventure)
		SaveSlots.save_into(adventure, 2, "By the river")
	return adventure


func _list() -> LoadAdventureScreen:
	var list: LoadAdventureScreen = load("res://game/adventure/load_adventure_screen.tscn").instantiate()
	add_child_autofree(list)
	await _frames(1)
	return list


func _note(list: LoadAdventureScreen) -> String:
	return (list.find_child("Note", true, false) as Label).text


func _files(folder: String) -> Dictionary:
	var out := {}
	if not DirAccess.dir_exists_absolute(folder):
		return out
	for file_name in DirAccess.get_files_at(folder):
		out[file_name] = FileAccess.get_file_as_bytes(folder.path_join(file_name))
	return out


func _select(list: LoadAdventureScreen, path: String) -> void:
	for i in list.rows.size():
		if not list.rows[i].is_empty() and String(list.rows[i]["path"]) == path:
			(list.find_child("Saves", true, false) as ItemList).select(i)
			list._sync_buttons(i)
			return
	fail_test("no row for " + path)


func _press(ask: Control, button: String) -> void:
	await _frames(1)
	var choice := ask.find_child(button, true, false) as Button
	assert_not_null(choice, button)
	if choice != null:
		choice.pressed.emit()
	await _frames(2)


# ------------------------------------------------------------- buttons --

func test_export_needs_a_save_highlighted_and_import_never_does() -> void:
	var empty := await _list()
	assert_true(empty.export_button.disabled, "nothing saved: nothing to export")
	assert_false(empty.import_button.disabled, "but an adventure can be brought in")
	empty.queue_free()
	_saved()
	var list := await _list()
	assert_false(list.export_button.disabled, "a save is highlighted")
	(list.find_child("Saves", true, false) as ItemList).select(0)
	list._sync_buttons(0)
	assert_true(list.export_button.disabled, "the hero's line is no save")
	assert_true(list.delete_button.disabled)
	assert_false(list.import_button.disabled)
	assert_string_contains(list.export_button.tooltip_text, "Ctrl+E")
	assert_string_contains(list.import_button.tooltip_text, "Ctrl+I")


func test_the_buttons_fit_the_smallest_window_side_by_side() -> void:
	_saved()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var list: LoadAdventureScreen = load("res://game/adventure/load_adventure_screen.tscn").instantiate()
	viewport.add_child(list)
	await _frames(2)
	var whole := Rect2(Vector2.ZERO, Vector2(1280, 800))
	var order := [list.hall_button, list.export_button, list.import_button, list.delete_button,
		list.back_button, list.resume_button]
	for i in order.size():
		var box := (order[i] as Button).get_global_rect()
		assert_true(whole.encloses(box), "%s inside the window" % (order[i] as Button).text)
		if i > 0:
			assert_lt((order[i - 1] as Button).get_global_rect().end.x, box.position.x,
				"%s after %s" % [(order[i] as Button).text, (order[i - 1] as Button).text])
	assert_eq(list.hall_button.get_index(), 0, "the Hall still at the far left")
	assert_eq(list.back_button.get_index() + 1, list.resume_button.get_index(), "Back beside Resume")


# ---------------------------------------------------------- round trip --

func test_export_then_import_brings_the_adventure_back_and_it_resumes() -> void:
	var goya := _saved()
	var before := _files(SAVES)
	var list := await _list()
	_select(list, goya.save_path(SaveSlots.QUICK_KIND))
	var zip := OUT.path_join("Goya.zip")
	assert_true(list.export_to(zip))
	assert_eq(_note(list), "Exported Goya's adventure: 3 saves in Goya.zip.")
	assert_true(FileAccess.file_exists(zip))
	_wipe(SAVES)
	list.refresh()
	assert_eq(list.saves.size(), 0, "gone from the list")
	assert_true(list.import_from(zip))
	assert_eq(_note(list), "Imported Goya's adventure: 3 saves.")
	assert_eq(_files(SAVES), before, "every file back, byte for byte")
	var row := list.highlighted()
	assert_eq(String(row.get("id", "")), goya.adventure_id, "the imported adventure highlighted")
	assert_eq(int(row.get("slot", -9)), 0, "on its autosave")
	assert_false(list.export_button.disabled)
	assert_true(list.resume())
	await _frames(2)
	var world: WorldScreen = null
	for node in get_tree().root.get_children():
		if node is WorldScreen and not node.is_queued_for_deletion():
			world = node
	assert_not_null(world, "the imported adventure is taken up")
	if world != null:
		assert_eq([world.player.adventure_id, world.player.gold], [goya.adventure_id, 250])


func test_an_export_without_zip_on_its_name_writes_nothing() -> void:
	_saved()
	var list := await _list()
	assert_false(list.export_to(OUT.path_join("Goya.txt")))
	assert_string_contains(_note(list), "ending in .zip")
	assert_eq(DirAccess.get_files_at(OUT).size(), 0)


func test_a_refused_zip_says_why_and_writes_nothing() -> void:
	var goya := _saved()
	var before := _files(SAVES)
	var list := await _list()
	var junk := OUT.path_join("holiday.zip")
	var file := FileAccess.open(junk, FileAccess.WRITE)
	file.store_string("not a zip")
	file.close()
	assert_false(list.import_from(junk))
	assert_eq(_note(list), AdventureTransfer.NOT_EXPORTED % "holiday.zip")
	assert_false(list.replace_shown())
	assert_eq(_files(SAVES), before)
	assert_ne(goya.adventure_id, "")


# ---------------------------------------------------- replace or cancel --

func test_an_adventure_here_already_asks_and_cancel_keeps_it() -> void:
	var goya := _saved()
	var list := await _list()
	_select(list, goya.save_path())
	var zip := OUT.path_join("Goya.zip")
	assert_true(list.export_to(zip))
	goya.gold = 9
	goya.autosave()
	var here := _files(SAVES)
	assert_false(list.import_from(zip), "asked first")
	assert_true(list.replace_shown())
	await _press(list._replace_ask, "Cancel")
	assert_false(list.replace_shown())
	assert_eq(_note(list), "Nothing was imported.")
	assert_eq(_files(SAVES), here, "every save as it was")
	# Escape cancels too.
	list.import_from(zip)
	await _frames(1)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	list._replace_ask._unhandled_input(escape)
	await _frames(2)
	assert_false(list.replace_shown())
	assert_eq(_files(SAVES), here)
	assert_true(is_instance_valid(list) and not list.is_queued_for_deletion(), "the list stays up")


func test_replace_puts_the_imported_saves_in_place() -> void:
	var goya := _saved()
	var exported := _files(SAVES)
	var list := await _list()
	_select(list, goya.save_path())
	var zip := OUT.path_join("Goya.zip")
	assert_true(list.export_to(zip))
	SaveSlots.save_into(goya, 6, "A detour")
	list.refresh()
	list.import_from(zip)
	assert_true(list.replace_shown())
	var words := (list._replace_ask as LoadAdventureScreen.ReplaceAsk).words
	assert_string_contains(words, "Goya's adventure is here already, with 4 saves.")
	assert_string_contains(words, "Replace them with the 3 imported saves?")
	await _press(list._replace_ask, "Replace")
	assert_eq(_note(list), "Imported Goya's adventure: 3 saves.")
	assert_eq(_files(SAVES), exported, "the adventure as it was exported")
	assert_eq(String(list.highlighted().get("id", "")), goya.adventure_id)


func test_newer_saves_here_are_named_in_the_question() -> void:
	var goya := _saved()
	var list := await _list()
	_select(list, goya.save_path())
	var zip := OUT.path_join("Goya.zip")
	assert_true(list.export_to(zip))
	# Saved again after the export, later on the clock.
	var path := goya.save_path()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	data["adventure"]["saved"] = "2099-01-01T12:00:00Z"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	list.import_from(zip)
	assert_true(list.replace_shown())
	var words := (list._replace_ask as LoadAdventureScreen.ReplaceAsk).words
	assert_string_contains(words, "The saves here are newer")
	assert_string_contains(words, AdventurePlayer.local_time("2099-01-01T12:00:00Z"))
	await _press(list._replace_ask, "Cancel")
	assert_eq(JSON.parse_string(FileAccess.get_file_as_string(path))["adventure"]["saved"], "2099-01-01T12:00:00Z")


func test_the_adventure_being_played_is_not_imported_over() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var screen := WorldScreen.new()
	screen.record = _setup().resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.player.monsters = [] as Array
	var id := screen.player.adventure_id
	assert_ne(screen.player.autosave(), "", "the adventure being played is saved")
	var list := screen.open_load()
	assert_not_null(list)
	await _frames(1)
	var zip := OUT.path_join("Playing.zip")
	assert_true(list.export_to(zip, id))
	var here := _files(SAVES)
	assert_false(list.import_from(zip))
	assert_false(list.replace_shown(), "not even asked")
	assert_string_contains(_note(list), "is the one you are playing")
	assert_eq(_files(SAVES), here)


# ------------------------------------------------------ keys and browser --

## A browser's page as far as the screen speaks to it: a file box that has
## [param zip] chosen, read in slice by slice; and the downloads it is
## handed, in [param downloads].
func _page(list: LoadAdventureScreen, zip: PackedByteArray, downloads: Array) -> Dictionary:
	var page := {"state": "gone", "opened": 0, "scripts": []}
	list.on_web = true
	list.web_page = func(script: String) -> Variant:
		(page["scripts"] as Array).append(script)
		if script.contains("input.click()"):
			page["opened"] = int(page["opened"]) + 1
			page["state"] = "ready"
			return null
		if script.contains(".state : 'gone'"):
			return page["state"]
		if script == "window.shandalarAdventurePick.name":
			return "Goya.zip"
		if script.ends_with(".data.length"):
			return zip.size()
		if script.contains(".data.subarray("):
			var span := script.get_slice("subarray(", 1).trim_suffix(")").split(",")
			return zip.slice(int(span[0].strip_edges()), int(span[1].strip_edges()))
		if script.contains("= null"):
			page["state"] = "gone"
		return null
	list.web_download = func(bytes: PackedByteArray, file_name: String) -> void:
		downloads.append([file_name, bytes])
	return page


func _key(list: LoadAdventureScreen, code: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.ctrl_pressed = true
	press.pressed = true
	list._unhandled_input(press)
	await _frames(1)


func test_in_a_browser_ctrl_e_downloads_and_ctrl_i_reads_the_chosen_file() -> void:
	var goya := _saved()
	var before := _files(SAVES)
	var list := await _list()
	_select(list, goya.save_path())
	var downloads: Array = []
	_page(list, PackedByteArray(), downloads)
	await _key(list, KEY_E)
	assert_eq(downloads.size(), 1, "Ctrl+E: a download")
	var file_name := AdventureTransfer.file_name_for("Goya")
	assert_eq(String(downloads[0][0]), file_name)
	assert_eq(_note(list), "Exported Goya's adventure: 3 saves, downloaded as %s." % file_name)
	var zip: PackedByteArray = downloads[0][1]
	_wipe(SAVES)
	list.refresh()
	var page := _page(list, zip, downloads)
	await _key(list, KEY_I)
	assert_eq(int(page["opened"]), 1, "Ctrl+I: the page's file box")
	for i in 5:
		await _frames(1)
	assert_eq(_note(list), "Imported Goya's adventure: 3 saves.")
	assert_eq(_files(SAVES), before, "byte for byte, through the page")
	assert_false(FileAccess.file_exists(AdventureTransfer.INCOMING), "nothing left in the game's folder")
	assert_eq(String(page["state"]), "gone", "the page's copy let go")
