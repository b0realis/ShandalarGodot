extends GutTest
## `[QoL]` THE SKIN ROWS — the Options screen's `Skin:` section
## (`game/options_screen.gd`, `_add_skin_section`), asked for on
## 2026-09-08: *"we should have a menu options to select asset art skin
## by file choosing"*, and redrawn the same day: *"it should just say
## 'skin', point to skin zip in skins folder. Then it should be a
## checkbox — 'use art folder instead of zip' (the default folder
## location should be shown in settings but can also be changed in
## cfg) … additional music folder … Additional Portraits folder … Card
## folder … Write in settings also that these folder locations can be
## changed in the cfg file!"* One row per zip [SkinPack] knows, each
## with a `Choose...`; the folder switch; a row per place the player
## can fill; a `Forget my zips` that shows only while the player keeps
## one; the note naming the keys; and the rows re-read themselves when
## a pack arrives. The file box itself is the platform's and is not
## opened here; what is pinned is the screen around it.

const SCRATCH := "user://options_skin_test"
const ART := SCRATCH + "/art.zip"
const ASIDE := SCRATCH + "/aside"
const PACKS := SCRATCH + "/cardpacks"
const PORTRAITS := SCRATCH + "/portraits"
const MUSIC := SCRATCH + "/music"
## Remembered and put back — never written back as a default.
const KEYS: Array[String] = [GamePaths.KEY_CARDPACKS, GamePaths.KEY_SKIN_ZIP,
	GamePaths.KEY_USE_SKIN_FOLDER, GamePaths.KEY_SKIN_FOLDER]

var screen: Control
var _was_mounted := false
var _aside: Array[String] = []
var _saved: Dictionary = {}
var _portrait_dirs: Array[String] = []
var _music_dirs: Array[String] = []


func before_each() -> void:
	_was_mounted = GameSkin.pack_mounted
	for folder in [SCRATCH, ASIDE, PACKS, PORTRAITS, MUSIC]:
		DirAccess.make_dir_recursive_absolute(folder)
	_saved = {}
	for key in KEYS:
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)
	Settings.set_value(GamePaths.KEY_CARDPACKS, PACKS)
	_portrait_dirs = PortraitLibrary.dirs
	PortraitLibrary.dirs = [PORTRAITS, PortraitLibrary.DEFAULT_DIRS[1], PortraitLibrary.DEFAULT_DIRS[2]]
	_music_dirs = MusicLibrary.dirs
	MusicLibrary.dirs = [MUSIC]
	_aside = []
	for path in SkinPack._zips_in(SkinPack.USER_DIR):
		DirAccess.rename_absolute(path, ASIDE.path_join(path.get_file()))
		_aside.append(path)
	var img := Image.create(4, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color.ORANGE_RED)
	var packer := ZIPPacker.new()
	assert(packer.open(ART) == OK)
	packer.start_file("skin/cardart/zz_probe_card.png")
	packer.write_file(img.save_png_to_buffer())
	packer.close_file()
	packer.close()
	screen = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	GameSkin.pack_mounted = _was_mounted
	GameSkin.clear_caches()
	SkinPack._hide_notice()
	PortraitLibrary.dirs = _portrait_dirs
	PortraitLibrary.refresh()
	MusicLibrary.dirs = _music_dirs
	MusicLibrary.refresh()
	for path in SkinPack._zips_in(SkinPack.USER_DIR):
		DirAccess.remove_absolute(path)
	for path in _aside:
		DirAccess.rename_absolute(ASIDE.path_join(path.get_file()), path)
	for key in KEYS:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])
	for folder in [PACKS, PORTRAITS, MUSIC, ASIDE, SCRATCH]:
		for name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(name))
		DirAccess.remove_absolute(folder)


func _walk(node: Node) -> Array:
	var out := [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


func _labels() -> PackedStringArray:
	var out := PackedStringArray()
	for node in _walk(screen):
		if node is Label:
			out.append((node as Label).text)
	return out


func _label(node_name: String) -> Label:
	return screen.find_child(node_name, true, false) as Label


func test_the_section_has_a_row_per_zip_and_a_chooser_on_each() -> void:
	assert_has(_labels(), "Skin:", "the section is headed like the others")
	for kind in SkinPack.KINDS:
		var status := _label("SkinStatus_" + kind)
		assert_not_null(status, "a status line for " + kind)
		if status != null:
			assert_true(status.text.begins_with("Card folder:" if kind == "cardart" else "Skin:"),
				status.text)
		var choose := screen.find_child("Choose_" + kind, true, false) as Button
		assert_not_null(choose, "a chooser for " + kind)
		if choose != null:
			assert_eq(choose.text, "Choose...")
	assert_string_contains(_label("SkinStatus_cardart").text,
		GamePaths.shown(PACKS), "the card row names the card folder")
	assert_true(FileAccess.file_exists(PACKS.path_join(SkinPack.CARD_README_NAME)),
		"which exists from the first look, README and all")


func test_the_skin_row_comes_right_after_display() -> void:
	var labels := _labels()
	var display := labels.find("Display:")
	var skin := labels.find("Skin:")
	var sound := labels.find("Sound:")
	assert_true(display >= 0 and skin > display and sound > skin,
		"Display, then Skin, then Sound: %d / %d / %d" % [display, skin, sound])


## *"the default folder location should be shown in settings"* — every
## place the player can fill is named by a path they can open, with what
## is in it.
func test_every_place_is_named_by_its_path() -> void:
	var folder := _label("SkinFolder")
	assert_not_null(folder)
	if folder != null:
		assert_true(folder.text.begins_with("Skin folder: "), folder.text)
		assert_string_contains(folder.text, GamePaths.shown(GamePaths.skin_folder()))
	var portraits := _label("PortraitsFolder")
	assert_not_null(portraits)
	if portraits != null:
		assert_eq(portraits.text, screen.portraits_line(GamePaths.shown(PORTRAITS), 0))
		assert_string_contains(portraits.text, "none yet")
		assert_ne(portraits.tooltip_text, "", "the how is the tooltip")
		assert_eq(portraits.mouse_filter, Control.MOUSE_FILTER_PASS, "so the tooltip can show")
	var music := _label("MusicFolder")
	assert_not_null(music)
	if music != null:
		assert_eq(music.text, screen.music_line(GamePaths.shown(MUSIC), 0))
	assert_true(FileAccess.file_exists(PORTRAITS.path_join(PortraitLibrary.README_NAME)),
		"the portraits folder exists from the first look")
	assert_true(FileAccess.file_exists(MUSIC.path_join(MusicLibrary.README_NAME)))


## The rows' words, against any count — statics, so the phrasing is
## pinned without a folder to fill. One line each (the owner: *"Too
## much text"*); what goes there is the tooltip's to say.
func test_the_folder_lines_say_what_the_player_can_put_there() -> void:
	assert_eq(screen.skin_folder_line("~/x/original_skin", false, 0),
		"Skin folder: ~/x/original_skin — not there yet")
	assert_eq(screen.skin_folder_line("~/x/original_skin", true, 1),
		"Skin folder: ~/x/original_skin — 1 file")
	assert_eq(screen.skin_folder_line("~/x/original_skin", true, 236),
		"Skin folder: ~/x/original_skin — 236 files")
	assert_eq(screen.portraits_line("~/x/portraits", 0),
		"Additional portraits folder: ~/x/portraits — none yet")
	assert_eq(screen.portraits_line("~/x/portraits", 3),
		"Additional portraits folder: ~/x/portraits — 3 of yours")
	assert_eq(screen.music_line("~/x/music", 0),
		"Additional music folder: ~/x/music — none yet")
	assert_eq(screen.music_line("~/x/music", 1),
		"Additional music folder: ~/x/music — 1 track of yours")
	assert_eq(screen.music_line("~/x/music", 12),
		"Additional music folder: ~/x/music — 12 tracks of yours")


func test_the_folder_rows_count_what_the_player_put_there() -> void:
	var img := Image.create(4, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color.SEA_GREEN)
	img.save_png(PORTRAITS + "/zz_me.png")
	img.save_png(PORTRAITS + "/zz_you.png")
	var tune := FileAccess.open(MUSIC + "/zz_tune.ogg", FileAccess.WRITE)
	tune.store_string("not really a tune; counted by its name")
	tune.close()
	screen._on_skin_changed("")
	assert_string_contains(_label("PortraitsFolder").text, "2 of yours")
	assert_string_contains(_label("MusicFolder").text, "1 track of yours")


## *"(The user wants to use this and not zip!)"* — the switch writes the
## key at once, says when it takes effect, and the rows re-read.
func test_the_folder_switch_writes_its_key_and_says_when_it_takes_effect() -> void:
	var use_folder := screen.find_child("UseSkinFolder", true, false) as CheckButton
	assert_not_null(use_folder)
	if use_folder == null:
		return
	assert_false(use_folder.button_pressed, "off unless the key says so")
	var hint := _label("SkinHint")
	assert_false(hint.visible, "no hint until the switch moves")
	use_folder.button_pressed = true
	assert_true(GamePaths.use_skin_folder())
	assert_true(Settings.has_value(GamePaths.KEY_USE_SKIN_FOLDER))
	assert_true(hint.visible)
	assert_eq(hint.text, "The folder is worn from the next start; the zip stays closed.")
	use_folder.button_pressed = false
	assert_false(GamePaths.use_skin_folder())
	assert_eq(hint.text, "The zip is worn from the next start.")


func test_the_switch_opens_on_what_the_key_says() -> void:
	Settings.set_value(GamePaths.KEY_USE_SKIN_FOLDER, true)
	var again: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(again)
	await get_tree().process_frame
	var use_folder := again.find_child("UseSkinFolder", true, false) as CheckButton
	assert_true(use_folder.button_pressed)


## *"Write in settings also that these folder locations can be changed
## in the cfg file!"* — then *"All this info document in text files not
## here in the gui"*: one line, naming the file and where the how is.
func test_the_note_is_one_line_naming_the_settings_file() -> void:
	var note := _label("SkinNote")
	assert_not_null(note)
	if note == null:
		return
	assert_string_contains(note.text, "settings.cfg")
	assert_string_contains(note.text, "setup.txt")
	assert_true(note.text.length() < 140, "one line, not a manual: %d" % note.text.length())
	assert_eq(note.text, screen.places_note(false))
	var web: String = screen.places_note(true)
	assert_false("settings.cfg" in web, "a browser has no file to edit")
	assert_true(web.length() < 60)


## *"Do we need forget my zips button?"* — not where the row names the
## folder the zip is in: the desktop builds none. A browser has no
## folder to open, so there it stays (built under the web feature only).
func test_forget_is_not_built_where_the_folder_can_be_opened() -> void:
	assert_null(screen.find_child("ForgetSkins", true, false),
		"the desktop names the folder instead")


func test_the_chooser_is_row_sized() -> void:
	for kind in SkinPack.KINDS:
		var choose := screen.find_child("Choose_" + kind, true, false) as Button
		assert_true(choose.custom_minimum_size.y <= 28, "row height: %s" % choose.custom_minimum_size)
		assert_true(choose.custom_minimum_size.x <= 100)
		assert_eq(choose.size_flags_vertical, Control.SIZE_SHRINK_CENTER)


func test_the_rows_re_read_themselves_when_a_zip_arrives() -> void:
	var status := _label("SkinStatus_cardart")
	var before := status.text
	# A drop is what a chosen file becomes once the box has answered:
	# both go through SkinPack.adopt. Off the title the pack offers a
	# restart rather than reloading anything — and an earlier suite may
	# have left the title as the tree's current scene (a Back button
	# changes to main.tscn for the rest of the run), so the scene is
	# pinned to a stand-in, as test_skin_pack.gd does.
	var was := get_tree().current_scene
	var elsewhere := Node.new()
	get_tree().root.add_child(elsewhere)
	get_tree().current_scene = elsewhere
	assert_true(SkinPack.adopt(ProjectSettings.globalize_path(ART)))
	get_tree().current_scene = was
	elsewhere.queue_free()
	assert_true(FileAccess.file_exists(PACKS + "/art.zip"), "kept in the card folder by name")
	assert_ne(status.text, before)
	assert_string_contains(status.text, "art.zip (1 picture, your own)")
	assert_not_null(SkinPack.notice(), "the pack's own notice, over this screen")


func test_the_transfer_line_stays_down_when_nothing_is_read_in() -> void:
	var line := _label("SkinTransfer")
	assert_not_null(line)
	if line != null:
		assert_false(line.visible)
		SkinPack.fetch_progressed.emit(0.5)
		assert_false(line.visible, "follows the pack's own flags, not the signal alone")


func test_leaving_the_screen_lets_go_of_the_packs_signals() -> void:
	var before := SkinPack.changed.get_connections().size()
	var progress_before := SkinPack.fetch_progressed.get_connections().size()
	assert_true(SkinPack.changed.is_connected(screen._on_skin_changed))
	screen.queue_free()
	await get_tree().process_frame
	assert_eq(SkinPack.changed.get_connections().size(), before - 1,
		"the pack's signal no longer names a freed screen")
	assert_eq(SkinPack.fetch_progressed.get_connections().size(), progress_before - 1)
