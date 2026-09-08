extends GutTest
## `[QoL]` THE SKIN ROWS — the Options screen's `Skin:` section
## (`game/options_screen.gd`, `_add_skin_section`), asked for on
## 2026-09-08: *"we should have a menu options to select asset art skin
## by file choosing."* Two rows, one per zip [SkinPack] knows — the
## 1997 art and the card pictures — each saying what dresses the game
## and carrying a `Choose...`; a `Forget my zips` that shows only while
## the player keeps one; and the rows re-read themselves when a pack
## arrives. The file box itself is the platform's and is not opened
## here; what is pinned is the screen around it.

const SCRATCH := "user://options_skin_test"
const ART := SCRATCH + "/art.zip"
const ASIDE := SCRATCH + "/aside_%s.zip"

var screen: Control
var _was_mounted := false
var _had_user_zip: Dictionary = {}


func before_each() -> void:
	_was_mounted = GameSkin.pack_mounted
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	for kind in SkinPack.KINDS:
		_had_user_zip[kind] = FileAccess.file_exists(SkinPack.user_zip(kind))
		if _had_user_zip[kind]:
			DirAccess.rename_absolute(SkinPack.user_zip(kind), ASIDE % kind)
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
	for kind in SkinPack.KINDS:
		if FileAccess.file_exists(SkinPack.user_zip(kind)):
			DirAccess.remove_absolute(SkinPack.user_zip(kind))
		if _had_user_zip[kind]:
			DirAccess.rename_absolute(ASIDE % kind, SkinPack.user_zip(kind))
	for name in DirAccess.get_files_at(SCRATCH):
		DirAccess.remove_absolute(SCRATCH.path_join(name))
	DirAccess.remove_absolute(SCRATCH)


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


func test_the_section_has_a_row_per_zip_and_a_chooser_on_each() -> void:
	assert_has(_labels(), "Skin:", "the section is headed like the others")
	for kind in SkinPack.KINDS:
		var status := screen.find_child("SkinStatus_" + kind, true, false) as Label
		assert_not_null(status, "a status line for " + kind)
		if status != null:
			assert_true(status.text.begins_with("Card art:" if kind == "cardart" else "1997 art:"),
				status.text)
		var choose := screen.find_child("Choose_" + kind, true, false) as Button
		assert_not_null(choose, "a chooser for " + kind)
		if choose != null:
			assert_eq(choose.text, "Choose...")


func test_the_skin_row_comes_right_after_display() -> void:
	var labels := _labels()
	var display := labels.find("Display:")
	var skin := labels.find("Skin:")
	var sound := labels.find("Sound:")
	assert_true(display >= 0 and skin > display and sound > skin,
		"Display, then Skin, then Sound: %d / %d / %d" % [display, skin, sound])


func test_forget_is_hidden_until_the_player_keeps_a_zip() -> void:
	var forget := screen.find_child("ForgetSkins", true, false) as Button
	assert_not_null(forget)
	if forget == null:
		return
	assert_false(forget.visible, "nothing of the player's own under the editor")


func test_the_rows_re_read_themselves_when_a_zip_arrives() -> void:
	var status := screen.find_child("SkinStatus_cardart", true, false) as Label
	var forget := screen.find_child("ForgetSkins", true, false) as Button
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
	assert_true(FileAccess.file_exists(SkinPack.USER_ART_ZIP))
	assert_ne(status.text, before)
	assert_string_contains(status.text, "your own")
	assert_string_contains(status.text, "1 picture,")
	assert_true(forget.visible, "and the way back appears")
	assert_not_null(SkinPack.notice(), "the pack's own notice, over this screen")


func test_the_transfer_line_stays_down_when_nothing_is_read_in() -> void:
	var line := screen.find_child("SkinTransfer", true, false) as Label
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
