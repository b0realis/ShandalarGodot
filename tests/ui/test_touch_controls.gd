extends GutTest
## THE TOUCH LAYER — the `TouchControls` autoload
## (`game/input/touch_controls.gd`), the stored key behind it
## (`Settings.touch_controls`) and the Options row that shows it.
##
## `[QoL]`, 2026-09-07: *"touch control support if enabled/present, for
## online web export and play via mobiles/tablets."* [TouchGestures]
## pins the vocabulary with a hand-held clock; this file pins what the
## layer DOES with it against real controls, driven through
## `Input.parse_input_event` — the engine's own path, mouse emulation and
## all — so the swallowing and the synthesis are tested where they live:
##
##   1. INERT unless asked. Headless there is no touchscreen, so `auto`
##      is off, the node processes nothing, and a real mouse click is the
##      same click it always was. Forced `on`, a real mouse is STILL left
##      alone — only the engine's emulated events are replaced.
##   2. The map, on plain controls: tap clicks (and the engine's own
##      emulated click is eaten, so it clicks once); touch-down hovers;
##      long-press and lift right-clicks; a drag presses at the origin,
##      moves and releases; two fingers right-click; a one-finger drag on
##      something that scrolls, where nothing scrolls natively, spends
##      wheel notches; a fat tap beside a small button reaches it.
##   3. The map, on the duel table: touching a card docks its preview,
##      holding one opens its menu, dragging one places it.
##   4. The switch: the Options row is a view of the key, and turning the
##      layer off mid-drag lets the button go.

## Where the OS window's coordinates and the viewport's differ (headless
## they do), a touch has to be sent in the window's — the engine maps it
## back, exactly as it maps a real finger. The way back is a float
## inverse, so positions are compared to a hundredth of a pixel.
var _xform: Transform2D
## Every scene under test sits on its own [CanvasLayer] ABOVE the test
## runner's panel, which is drawn over the top-left of the viewport and
## would otherwise be what a touch there hovers.
var _stage: CanvasLayer
var layer: Node
var _saved: Variant = null
var _table: Control
var _button: Button
var _seen: Array[InputEvent] = []
var _made: Array[InputEvent] = []
var _presses := 0


func before_each() -> void:
	layer = get_tree().root.get_node_or_null("TouchControls")
	assert_not_null(layer, "the autoload is in the tree")
	_xform = get_tree().root.get_final_transform()
	_saved = Settings.get_value(TouchControls.KEY, null) \
		if Settings.has_value(TouchControls.KEY) else null
	Settings.clear_value(TouchControls.KEY)
	layer.apply_settings()
	_seen.clear()
	_made.clear()
	_presses = 0
	layer.synthesized.connect(_on_made)


func after_each() -> void:
	layer.synthesized.disconnect(_on_made)
	if _saved == null:
		Settings.clear_value(TouchControls.KEY)
	else:
		Settings.set_value(TouchControls.KEY, _saved)
	layer.apply_settings()
	await get_tree().process_frame


func _on_made(event: InputEvent) -> void:
	_made.append(event)


# ------------------------------------------------------------- helpers --

## The 1280x800 the screens are laid out for, on a layer of its own.
func _build_stage() -> void:
	_stage = CanvasLayer.new()
	_stage.layer = 200
	add_child_autofree(_stage)
	_table = Control.new()
	_table.size = Vector2(1280, 800)
	_stage.add_child(_table)


## A plain table with one button on it, recording what reaches the button.
func _build_table() -> void:
	_build_stage()
	_button = Button.new()
	_button.text = "hit me"
	_button.position = Vector2(200, 200)
	_button.size = Vector2(120, 40)
	_button.gui_input.connect(func(ev: InputEvent) -> void: _seen.append(ev))
	_button.pressed.connect(func() -> void: _presses += 1)
	_table.add_child(_button)


func _finger(index: int, at: Vector2, pressed: bool) -> void:
	var st := InputEventScreenTouch.new()
	st.index = index
	st.position = _xform * at
	st.pressed = pressed
	Input.parse_input_event(st)


func _move(index: int, at: Vector2) -> void:
	var sd := InputEventScreenDrag.new()
	sd.index = index
	sd.position = _xform * at
	sd.relative = Vector2(1, 1)
	Input.parse_input_event(sd)


func _mouse(button: int, at: Vector2, pressed: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = button
	mb.pressed = pressed
	mb.position = _xform * at
	mb.global_position = mb.position
	mb.device = 0           # a real pointer
	Input.parse_input_event(mb)


## The engine delivers parsed events next frame; the layer spends them
## at its `_process` of that frame, which comes after `process_frame`.
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _made_buttons() -> Array:
	var out := []
	for ev in _made:
		if ev is InputEventMouseButton:
			out.append([ev.button_index, ev.pressed])
	return out


func _seen_devices() -> Array:
	var out := []
	for ev in _seen:
		if ev is InputEventMouseButton:
			out.append(ev.device)
	return out


func _tap(at: Vector2) -> void:
	_finger(0, at, true)
	await _settle()
	_finger(0, at, false)
	await _settle()


func _near(got: Vector2, want: Vector2, text := "") -> void:
	assert_true(got.distance_to(want) < 0.01, "%s is %s: %s" % [got, want, text])


# ====================================================== inert unless asked (1) ==

func test_the_key_reads_auto_until_asked_otherwise() -> void:
	assert_eq(TouchControls.KEY, "touch_controls")
	assert_eq(Settings.touch_controls(), "auto")
	assert_false(Settings.has_value(TouchControls.KEY), "nothing materialized into the file")
	Settings.set_value(TouchControls.KEY, "sideways", false)
	assert_eq(Settings.touch_controls(), "auto", "a value that is not one of the three is auto")
	Settings.clear_value(TouchControls.KEY)


func test_headless_there_is_no_touchscreen_so_auto_is_off() -> void:
	assert_false(DisplayServer.is_touchscreen_available())
	assert_false(TouchControls.platform_wants_touch())
	assert_false(TouchControls.should_be_active())
	assert_false(layer.is_active())
	assert_false(layer.is_processing_input(), "nothing at _input")
	assert_false(layer.is_processing(), "nothing at _process")


func test_the_engine_settings_the_layer_builds_on() -> void:
	assert_true(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true),
		"the engine's finger-as-mouse stays on: it keeps Input's mouse position under the finger")
	assert_false(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false),
		"and a mouse is never dressed up as a finger")
	assert_eq(int(ProjectSettings.get_setting("display/window/handheld/orientation", 0)),
		DisplayServer.SCREEN_SENSOR_LANDSCAPE, "handhelds hold the 1280x800 table sideways")


func test_off_a_real_mouse_click_is_the_click_it_always_was() -> void:
	_build_table()
	await _settle()
	_mouse(MOUSE_BUTTON_LEFT, Vector2(260, 220), true)
	_mouse(MOUSE_BUTTON_LEFT, Vector2(260, 220), false)
	await _settle()
	assert_eq(_presses, 1)
	assert_eq(_made.size(), 0, "nothing synthesized")
	assert_eq(_seen_devices(), [0, 0], "the pointer's own events, untouched")


func test_off_a_touch_is_the_engines_own_emulated_click() -> void:
	# What a touchscreen gets with the layer off: Godot's emulation, the
	# press landing at once. The layer being off is what this pins.
	_build_table()
	await _settle()
	await _tap(Vector2(260, 220))
	assert_eq(_presses, 1)
	assert_eq(_made.size(), 0)
	assert_eq(_seen_devices(), [InputEvent.DEVICE_ID_EMULATION, InputEvent.DEVICE_ID_EMULATION],
		"the engine's emulated press and release reached the button")
	var touches := 0
	for ev in _seen:
		if ev is InputEventScreenTouch:
			touches += 1
	assert_eq(touches, 2, "and so did the raw touch and its lift, as the engine sends them")


func test_on_a_real_mouse_is_still_left_alone() -> void:
	layer.choose(TouchControls.ON)
	assert_true(layer.is_active())
	_build_table()
	await _settle()
	_mouse(MOUSE_BUTTON_LEFT, Vector2(260, 220), true)
	_mouse(MOUSE_BUTTON_LEFT, Vector2(260, 220), false)
	await _settle()
	assert_eq(_presses, 1)
	assert_eq(_made.size(), 0, "a real pointer is never rewritten, even with the layer on")
	assert_eq(_seen_devices(), [0, 0])


# ======================================================= the map, plain (2) ==

func test_a_tap_clicks_once_and_the_engines_emulated_click_is_eaten() -> void:
	layer.choose(TouchControls.ON)
	_build_table()
	await _settle()
	await _tap(Vector2(260, 220))
	assert_eq(_presses, 1, "one click, not the engine's and ours both")
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_LEFT, false]])
	assert_eq(_seen_devices(), [TouchControls.SYNTH_DEVICE, TouchControls.SYNTH_DEVICE],
		"the button events the control saw were ours; the emulated ones never arrived")
	for ev in _seen:
		assert_false(ev is InputEventScreenTouch,
			"and the raw touch never arrived either — a 4.7 Button presses itself from one")


func test_touch_down_hovers_before_anything_is_clicked() -> void:
	layer.choose(TouchControls.ON)
	_build_table()
	await _settle()
	var entered := [false]
	_button.mouse_entered.connect(func() -> void: entered[0] = true)
	_finger(0, Vector2(260, 220), true)
	await _settle()
	assert_true(entered[0], "the preview would dock here")
	assert_eq(get_tree().root.gui_get_hovered_control(), _button)
	assert_eq(_presses, 0, "and nothing has been clicked")
	assert_eq(_made_buttons(), [], "no button event yet — only the hover")
	_finger(0, Vector2(260, 220), false)
	await _settle()
	assert_eq(_presses, 1, "the lift is the click")


func test_a_long_press_and_lift_is_a_right_click() -> void:
	layer.choose(TouchControls.ON)
	_build_table()
	await _settle()
	_finger(0, Vector2(260, 220), true)
	await _settle()
	await get_tree().create_timer(TouchGestures.LONG_PRESS_MS / 1000.0 + 0.1).timeout
	assert_eq(layer.gestures().mode(), TouchGestures.Mode.LONG, "armed by the clock")
	assert_eq(_made_buttons(), [], "nothing sent at the mark")
	_finger(0, Vector2(260, 220), false)
	await _settle()
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_RIGHT, true], [MOUSE_BUTTON_RIGHT, false]])
	assert_eq(_presses, 0, "a right click is not a press of the button")
	assert_eq(_seen_devices(), [TouchControls.SYNTH_DEVICE, TouchControls.SYNTH_DEVICE],
		"and the button's gui_input saw the right click, as it does from a mouse")


func test_a_drag_presses_at_the_origin_moves_and_releases() -> void:
	layer.choose(TouchControls.ON)
	_build_table()
	await _settle()
	_finger(0, Vector2(260, 220), true)
	await _settle()
	_move(0, Vector2(265, 222))
	await _settle()
	assert_eq(_made_buttons(), [], "under the slop: still a tap in the making")
	_move(0, Vector2(300, 220))
	await _settle()
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true]], "past it: the press")
	var press: InputEventMouseButton = _made[_made.size() - 2]
	_near(press.position, Vector2(260, 220), "at the ORIGIN, where the finger landed")
	var motion: InputEventMouseMotion = _made[_made.size() - 1]
	_near(motion.position, Vector2(300, 220), "the motion, where the finger is")
	_near(motion.relative, Vector2(40, 0), "relative to the origin")
	assert_eq(motion.button_mask, MOUSE_BUTTON_MASK_LEFT, "with the button held")
	_move(0, Vector2(340, 230))
	await _settle()
	var more: InputEventMouseMotion = _made[_made.size() - 1]
	_near(more.relative, Vector2(40, 10), "relative to the last point")
	_finger(0, Vector2(340, 230), false)
	await _settle()
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_LEFT, false]])
	var release: InputEventMouseButton = _made[_made.size() - 1]
	_near(release.position, Vector2(340, 230), "let go where the finger left")
	assert_eq(_presses, 0, "let go outside the button, so no press — as under a mouse")


func test_two_fingers_are_a_right_click_at_the_first() -> void:
	layer.choose(TouchControls.ON)
	_build_table()
	await _settle()
	_finger(0, Vector2(260, 220), true)
	_finger(1, Vector2(300, 225), true)
	await _settle()
	_finger(1, Vector2(300, 225), false)
	await _settle()
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_RIGHT, true], [MOUSE_BUTTON_RIGHT, false]])
	var press: InputEventMouseButton = _made[_made.size() - 2]
	_near(press.position, Vector2(260, 220), "at the first finger")
	_finger(0, Vector2(260, 220), false)
	await _settle()
	assert_eq(_made_buttons().size(), 2, "the second lift sends nothing more")


func test_a_finger_on_something_that_scrolls_scrolls_it() -> void:
	layer.choose(TouchControls.ON)
	_build_table()
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(600, 100)
	scroll.size = Vector2(200, 100)
	var column := VBoxContainer.new()
	for i in 20:
		var line := Label.new()
		line.text = "line %d" % i
		line.custom_minimum_size.y = 30
		column.add_child(line)
	scroll.add_child(column)
	_table.add_child(scroll)
	await _settle()
	scroll.scroll_vertical = 200
	await _settle()
	_finger(0, Vector2(700, 150), true)
	await _settle()
	_move(0, Vector2(700, 155))
	await _settle()
	assert_eq(scroll.scroll_vertical, 200, "under the slop nothing moves")
	_move(0, Vector2(700, 190))
	await _settle()
	assert_eq(scroll.scroll_vertical, 160, "the finger went 40 px DOWN, so the content did")
	_move(0, Vector2(700, 240.5))
	await _settle()
	assert_eq(scroll.scroll_vertical, 110, "whole pixels; the half is carried")
	_move(0, Vector2(700, 241))
	await _settle()
	assert_eq(scroll.scroll_vertical, 109, "and spent when it adds up")
	_finger(0, Vector2(700, 241), false)
	await _settle()
	assert_eq(_made_buttons(), [], "no button at all: a scroll is not a drag or a tap")
	assert_eq(_presses, 0)


func test_a_drag_carries_drag_and_drop() -> void:
	# The deck builder moves cards with Godot's own drag-and-drop, which
	# the viewport starts from a LEFT press and motion with the button
	# held — the drag the layer types.
	layer.choose(TouchControls.ON)
	_build_table()
	var source := DragSource.new()
	source.position = Vector2(500, 500)
	source.size = Vector2(60, 80)
	_table.add_child(source)
	var target := DropTarget.new()
	target.position = Vector2(800, 500)
	target.size = Vector2(200, 200)
	_table.add_child(target)
	await _settle()
	_finger(0, Vector2(530, 540), true)
	await _settle()
	_move(0, Vector2(560, 540))
	await _settle()
	_move(0, Vector2(700, 560))
	await _settle()
	assert_true(get_viewport().gui_is_dragging(), "the viewport is carrying the data")
	_move(0, Vector2(900, 600))
	await _settle()
	_finger(0, Vector2(900, 600), false)
	await _settle()
	assert_eq(target.dropped, ["a card"], "and dropped it where the finger lifted")
	assert_false(get_viewport().gui_is_dragging())


class DragSource extends Control:
	func _get_drag_data(_at: Vector2) -> Variant:
		return "a card"


class DropTarget extends Control:
	var dropped: Array = []
	func _can_drop_data(_at: Vector2, _data: Variant) -> bool:
		return true
	func _drop_data(_at: Vector2, data: Variant) -> void:
		dropped.append(data)


func test_a_fat_tap_beside_a_small_button_reaches_it() -> void:
	layer.choose(TouchControls.ON)
	_build_table()
	var tiny := Button.new()
	tiny.text = "x"
	tiny.position = Vector2(900, 600)
	tiny.size = Vector2(20, 20)
	var hit := [0]
	tiny.pressed.connect(func() -> void: hit[0] += 1)
	_table.add_child(tiny)
	await _settle()
	await _tap(Vector2(930, 610))           # 10 px right of its edge, on the bare table
	assert_eq(hit[0], 1, "moved onto the button: the 44-px target a finger needs")
	await _tap(Vector2(960, 610))           # 40 px: too far to be meant
	assert_eq(hit[0], 1, "a tap well away from it stays where it fell")
	await _tap(Vector2(260, 220))
	assert_eq(_presses, 1, "a tap ON something that listens is never moved")


# ================================================== the map, on the table (3) ==

func _table_screen() -> DuelScreen:
	_build_stage()
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	_table.add_child(screen)        # full-rect anchors: it takes the stage's 1280x800
	await get_tree().process_frame
	await get_tree().process_frame
	return screen


func _bear_on(screen: DuelScreen) -> CardInstance:
	var g: MtgGame = screen.game
	var bear := CardInstance.new(CardRegistry.get_card("Grizzly Bears"), 94001, 0)
	g._instances[bear.id] = bear
	g._put_on_battlefield(bear, 0)
	screen._refresh()
	return bear


func _board_card(screen: DuelScreen, inst: CardInstance) -> MiniCard:
	var row: Container = screen._field_rows[0][DuelScreen.Row.CREATURES]
	for child in row.get_children():
		if child is MiniCard and (child as MiniCard).instance == inst:
			return child
	return null


func test_touching_a_card_docks_its_preview() -> void:
	layer.choose(TouchControls.ON)
	var screen := await _table_screen()
	var bear := _bear_on(screen)
	await _settle()
	var w := _board_card(screen, bear)
	assert_not_null(w, "the bear is on the table")
	var centre := w.get_global_rect().get_center()
	_finger(0, centre, true)
	await _settle()
	assert_eq(screen._card_preview._shown, bear, "shown the moment the finger lands")
	assert_false(screen._dragging)
	_finger(0, centre, false)
	await _settle()


func test_holding_a_card_and_lifting_opens_its_menu() -> void:
	layer.choose(TouchControls.ON)
	var screen := await _table_screen()
	var bear := _bear_on(screen)
	await _settle()
	var w := _board_card(screen, bear)
	var centre := w.get_global_rect().get_center()
	_finger(0, centre, true)
	await _settle()
	await get_tree().create_timer(TouchGestures.LONG_PRESS_MS / 1000.0 + 0.1).timeout
	assert_false(screen._card_menu.visible, "nothing opens under a resting finger")
	_finger(0, centre, false)
	await _settle()
	assert_true(screen._card_menu.visible, "the lift opens @MENU_SMALLCARD")
	assert_eq(screen._card_menu_inst, bear)
	screen._card_menu.hide()
	await _settle()


func test_dragging_a_card_places_it() -> void:
	layer.choose(TouchControls.ON)
	var screen := await _table_screen()
	var bear := _bear_on(screen)
	await _settle()
	var w := _board_card(screen, bear)
	var centre := w.get_global_rect().get_center()
	assert_false(screen._placements.has(bear.id))
	_finger(0, centre, true)
	await _settle()
	_move(0, centre + Vector2(40, 0))
	await _settle()
	assert_eq(screen._drag_inst, bear, "past the slop: the press armed the drag")
	_move(0, centre + Vector2(80, 10))
	await _settle()
	_move(0, centre + Vector2(120, 20))
	await _settle()
	assert_true(screen._dragging, "and the motion carried it")
	_finger(0, centre + Vector2(120, 20), false)
	await _settle()
	assert_true(screen._placements.has(bear.id), "the lift placed it")
	assert_false(screen._dragging)


# ================================================================ the switch (4) ==

func test_the_options_row_is_a_view_of_the_key() -> void:
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var row: OptionButton = screen.find_child("TouchControls", true, false)
	assert_not_null(row, "the Display rows carry a Touch controls choice")
	assert_eq(row.item_count, 3)
	assert_eq(row.selected, 0, "Auto, with nothing stored")
	row.select(1)
	row.item_selected.emit(1)
	assert_eq(Settings.touch_controls(), "on", "the key follows the row")
	assert_true(layer.is_active(), "and the layer follows the key at once")
	row.select(2)
	row.item_selected.emit(2)
	assert_eq(Settings.touch_controls(), "off")
	assert_false(layer.is_active())
	Settings.set_value(TouchControls.KEY, "on")
	var fresh: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(fresh)
	await get_tree().process_frame
	var again: OptionButton = fresh.find_child("TouchControls", true, false)
	assert_eq(again.selected, 1, "a stored `on` opens the row on On")


func test_the_choice_survives_a_reload_of_the_file() -> void:
	layer.choose(TouchControls.ON)
	Settings.reload()
	assert_eq(Settings.touch_controls(), "on", "the file carries it")


func test_switching_off_mid_drag_lets_the_button_go() -> void:
	layer.choose(TouchControls.ON)
	_build_table()
	await _settle()
	_finger(0, Vector2(260, 220), true)
	await _settle()
	_move(0, Vector2(300, 220))
	await _settle()
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true]], "held")
	layer.choose(TouchControls.OFF)
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_LEFT, false]],
		"released where the pointer was, so no screen is left holding it")
	assert_eq(layer.gestures().finger_count(), 0, "and every finger forgotten")
	_finger(0, Vector2(300, 220), false)
	await _settle()
	assert_eq(_made_buttons().size(), 2, "the finger's own lift, arriving later, is nobody's")
