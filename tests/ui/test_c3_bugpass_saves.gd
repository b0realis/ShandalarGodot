extends GutTest
## THE SAVES' PANES UNDER FAST HANDS (the bug pass after the campaign,
## 2026-10-23):
##  - r3-2: two Escapes in one frame on the Load list closed the list and
##    then left the world for the title — the second found the world under
##    a list already leaving. The list takes every Escape now.
##  - r3-3: two slots picked in one frame made the rows twice, and the first
##    name box, dropped, was still asked for the keys: an `ERROR` in the log
##    (the gate fails on one). The box is asked only while it is there.
## Keys and clicks go through the screen's own viewport.

const SAVES := "user://adventure_tests_c3_bugpass_saves"

var viewport: SubViewport
var screen: WorldScreen


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = WorldScreen.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.player.monsters = [] as Array


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


func _escape() -> void:
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	viewport.push_input(esc, true)
	var up := esc.duplicate() as InputEventKey
	up.pressed = false
	viewport.push_input(up, true)


func _press(node: Control) -> void:
	var at := node.get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)


func test_two_escapes_on_the_load_list_leave_only_the_list() -> void:
	assert_not_null(screen.open_load(), "control: the Load list over the world")
	await _frames()
	_escape()
	_escape()
	await _frames(3)
	assert_false(screen.loading(), "the list is closed")
	assert_false(screen._leaving, "and the world is not left for the title")


func test_two_slots_picked_in_one_frame_ask_the_keys_of_the_box_still_there() -> void:
	var pane := screen.save_now()
	assert_not_null(pane, "control: the saves' pane")
	await _frames()
	# The first pick a real click; the second in the same frame, before the
	# rows made again are laid out (a click would land by the old layout).
	_press(pane.find_child("Pick_1", true, false) as Control)
	assert_eq(pane.editing, 1, "control: the click picked slot 1")
	pane.edit(2)
	await _frames(3)
	assert_eq(pane.editing, 2, "the second pick holds")
	var box := pane.find_child("SlotName", true, false) as LineEdit
	assert_not_null(box)
	assert_true(box.has_focus(), "the name box there takes the keys")
