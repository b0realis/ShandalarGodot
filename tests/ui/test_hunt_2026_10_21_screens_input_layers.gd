extends GutTest
## THE SECOND BUG HUNT (2026-10-21), the screens: the touch, keyboard and
## pad layers.
##
##   1. A FINGER COULD NOT DRAG A SLIDER IN A SCROLLING PAGE.
##      `TouchControls._scroll_container_under` called a touch "scrollable"
##      whenever a ScrollContainer stood anywhere above it, so a finger on
##      the Options screen's volume or pace slider scrolled the page and
##      the handle never moved (only a tap changed it); a finger on a
##      scroll bar's thumb moved the page AGAINST the thumb. A slider or a
##      scroll bar under the finger is now dragged.
##   2. THE ON-SCREEN KEYBOARD TYPED NOTHING INTO A FIELD THE ARROWS
##      REACHED. A LineEdit starts editing as it takes the focus only when
##      no arrow action is held, and until then drops typed letters; the
##      board shows for it all the same, and its letters, Space and
##      Backspace did nothing (its Enter only closed it). A key of the
##      board now starts the editing first.
##   3. A PAD ARRIVING MID-PRESS KEPT THE LEFT BUTTON DOWN.
##      `PadControls._on_pads_changed` forgot every held button on a
##      CONNECT as well as on a disconnect, so the held A's release was
##      read as owed nothing and the left button stayed down until A was
##      pressed again — a card or a window dragged on under the pointer.

var _saved_touch: Variant = null
var _saved_board: Variant = null
var _saved_pad: Variant = null
var _xform: Transform2D
var _stage: CanvasLayer
var _table: Control


func before_each() -> void:
	_xform = get_tree().root.get_final_transform()
	_saved_touch = Settings.get_value(TouchControls.KEY, null) \
		if Settings.has_value(TouchControls.KEY) else null
	_saved_board = Settings.get_value(ScreenKeyboard.KEY, null) \
		if Settings.has_value(ScreenKeyboard.KEY) else null
	_saved_pad = Settings.get_value(PadControls.KEY, null) \
		if Settings.has_value(PadControls.KEY) else null
	_stage = CanvasLayer.new()
	_stage.layer = 200
	add_child_autofree(_stage)
	_table = Control.new()
	_table.size = Vector2(1280, 800)
	_stage.add_child(_table)


func after_each() -> void:
	for action in ["ui_down", "ui_up", "ui_left", "ui_right"]:
		Input.action_release(action)
	_restore(TouchControls.KEY, _saved_touch)
	_restore(ScreenKeyboard.KEY, _saved_board)
	_restore(PadControls.KEY, _saved_pad)
	_touch_layer().apply_settings()
	_board().apply_settings()
	_pad_layer().set_active(false)
	_pad_layer().apply_settings()
	get_viewport().gui_release_focus()
	await get_tree().process_frame


func _restore(key: String, value: Variant) -> void:
	if value == null:
		Settings.clear_value(key)
	else:
		Settings.set_value(key, value, false)


func _touch_layer() -> Node:
	return get_tree().root.get_node("TouchControls")


func _board() -> Node:
	return get_tree().root.get_node("ScreenKeyboard")


func _pad_layer() -> Node:
	return get_tree().root.get_node("PadControls")


func _settle(frames := 2) -> void:
	for _i in frames:
		await get_tree().process_frame


# ------------------------------------------------------------ 1. touch --

func _finger(at: Vector2, pressed: bool) -> void:
	var st := InputEventScreenTouch.new()
	st.index = 0
	st.position = _xform * at
	st.pressed = pressed
	Input.parse_input_event(st)


func _move(at: Vector2) -> void:
	var sd := InputEventScreenDrag.new()
	sd.index = 0
	sd.position = _xform * at
	sd.relative = Vector2(1, 1)
	Input.parse_input_event(sd)


## A scrolling page with a slider on top and twenty lines under it.
func _page() -> Array:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(600, 100)
	scroll.size = Vector2(300, 200)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 280
	var slider := HSlider.new()
	slider.max_value = 100
	slider.custom_minimum_size = Vector2(240, 30)
	column.add_child(slider)
	for i in 20:
		var line := Label.new()
		line.text = "line %d" % i
		line.custom_minimum_size.y = 30
		column.add_child(line)
	scroll.add_child(column)
	_table.add_child(scroll)
	return [scroll, slider]


func _swipe(start: Vector2, by: Vector2) -> void:
	_finger(start, true)
	await _settle()
	for step in [0.1, 0.35, 0.7, 1.0]:
		_move(start + by * step)
		await _settle()
	_finger(start + by, false)
	await _settle()


func test_a_finger_drags_a_slider_in_a_scrolling_page() -> void:
	_touch_layer().choose(TouchControls.ON)
	var parts := _page()
	var scroll: ScrollContainer = parts[0]
	var slider: HSlider = parts[1]
	await _settle()
	await _swipe(slider.get_global_rect().position + Vector2(6, 15), Vector2(180, 0))
	assert_gt(slider.value, 50.0, "the handle followed the finger")
	assert_eq(scroll.scroll_vertical, 0, "and the page stayed")


func test_a_finger_pulls_a_scroll_bar_its_own_way() -> void:
	_touch_layer().choose(TouchControls.ON)
	var scroll: ScrollContainer = _page()[0]
	await _settle()
	var bar := scroll.get_v_scroll_bar()
	await _swipe(bar.get_global_rect().position + Vector2(bar.size.x / 2.0, 10), Vector2(0, 60))
	assert_gt(scroll.scroll_vertical, 0, "the thumb pulled down takes the page down")


func test_a_finger_on_the_page_itself_still_scrolls_it() -> void:
	_touch_layer().choose(TouchControls.ON)
	var parts := _page()
	var scroll: ScrollContainer = parts[0]
	await _settle()
	scroll.scroll_vertical = 200
	await _settle()
	await _swipe(Vector2(700, 200), Vector2(0, 40))
	assert_almost_eq(scroll.scroll_vertical, 160, 2,
		"a line under the finger is the page: it follows the finger, 40 px")


# ---------------------------------------------------------- 2. keyboard --

func _key(label: String) -> Button:
	for button in _board()._keys:
		if button.text == label:
			return button
	return null


func _field() -> LineEdit:
	_board().choose(ScreenKeyboard.ON)
	var above := Button.new()
	above.position = Vector2(490, 200)
	above.size = Vector2(100, 30)
	_table.add_child(above)
	var field := LineEdit.new()
	field.position = Vector2(490, 300)
	field.size = Vector2(300, 36)
	_table.add_child(field)
	return field


func test_a_field_the_arrows_reached_takes_the_boards_letters() -> void:
	var field := _field()
	var submitted: Array[String] = []
	field.text_submitted.connect(func(text: String) -> void: submitted.append(text))
	await _settle()
	Input.action_press("ui_down")
	field.grab_focus()
	Input.action_release("ui_down")
	await _settle(3)
	var a := _key("a")
	assert_not_null(a, "the board is up for the field")
	if a == null:
		return
	a.pressed.emit()
	await _settle(3)
	_key("b").pressed.emit()
	await _settle(3)
	assert_eq(field.text, "ab", "the letters reach a field walked to")
	_key(ScreenKeyboard.BACKSPACE).pressed.emit()
	await _settle(3)
	assert_eq(field.text, "a", "and Backspace")
	_key(ScreenKeyboard.ENTER).pressed.emit()
	await _settle(3)
	assert_eq(submitted, ["a"] as Array[String], "and Enter submits it")


# --------------------------------------------------------------- 3. pad --

func _pad(button: int, pressed: bool, device := 0) -> void:
	var jb := InputEventJoypadButton.new()
	jb.device = device
	jb.button_index = button
	jb.pressed = pressed
	Input.parse_input_event(jb)


func test_a_pad_arriving_mid_press_does_not_hold_the_button_down() -> void:
	var layer := _pad_layer()
	Settings.set_value(PadControls.KEY, PadControls.ON, false)
	layer.apply_settings()
	var made: Array = []
	var on_made := func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			made.append([ev.button_index, ev.pressed])
	layer.synthesized.connect(on_made)
	_pad(JOY_BUTTON_A, true)
	await _settle()
	assert_true(layer._left_held, "control: A held is the left button held")
	Input.joy_connection_changed.emit(1, true)
	await _settle()
	_pad(JOY_BUTTON_A, false)
	await _settle()
	layer.synthesized.disconnect(on_made)
	assert_false(layer._left_held, "A let go is the left button let go")
	assert_eq(made, [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_LEFT, false]])


func test_a_pad_leaving_mid_press_still_lets_go() -> void:
	var layer := _pad_layer()
	Settings.set_value(PadControls.KEY, PadControls.ON, false)
	layer.apply_settings()
	_pad(JOY_BUTTON_A, true)
	await _settle()
	Input.joy_connection_changed.emit(0, false)
	await _settle()
	assert_false(layer._left_held, "the 2026-10-12 rule stands")
