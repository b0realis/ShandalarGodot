extends GutTest
## THE PAD LAYER — the `PadControls` autoload
## (`game/input/pad_controls.gd`), the stored key behind it
## (`Settings.pad_pointer`) and the Options row that shows it.
##
## `[QoL]`, 2026-09-27, the Steam Deck release: *"pad navigable duel along
## with one button dedicated to advance game stage."* The twin of
## [TouchControls]' test, driven the same way — `Input.parse_input_event`,
## the engine's own path — against real controls on a stage of their
## own, so the swallowing and the synthesis are pinned where they live:
##
##   1. INERT unless asked. `auto` follows the hardware; `off` processes
##      nothing; the duel's own buttons (RB, X, B, Start...) pass through
##      the layer untouched even while it is on.
##   2. The map: A is the left button (a focused button is NOT pressed a
##      second time by the engine's `ui_accept` — the event is eaten),
##      LB the right, RT and LT the same two again past a threshold with
##      a band under it (2026-09-28), two quick As a double-click, the
##      left stick the pointer (and a drag under a held A), the right
##      stick the wheel, the D-pad a hop to the nearest button ahead —
##      over what is really drawn there, past what is covered, past what
##      a scroll has scrolled away, and staying put with nothing ahead;
##      and (2026-09-28, the second Steam Deck playtest) a hop lands on
##      the SEEN part of a card, so a stepped pile is walked band by
##      band, and a plate marked `pad_target` is a target like a button.
##   3. Awake and asleep: the first pad touch wakes the arrow where the
##      focus is — or where the mouse went since, a Deck's trackpad
##      having put it on a card for the trigger to click; a real mouse
##      puts it to sleep; turning the layer off releases what it held.
##   4. A mini-menu (an embedded window) takes the pad itself while it
##      is open — the engine's rule, pinned here so the layer never
##      fights it; and when the A that opened a menu is the one the menu
##      takes (2026-09-29), the layer lets that A go itself, so the next
##      A is a press and not a dropped copy.
##   5. The switch: the Options row is a view of the key.
##   6. One press is one press (2026-09-28): a real mouse press that
##      doubles the pad's own within DOUBLED_MS — Steam's copy of the
##      gesture, either order — is one press, and a second pad reporting
##      the same button is not a second press.

var _xform: Transform2D
var _stage: CanvasLayer
var layer: Node
var _saved: Variant = null
var _table: Control
var _button: Button
var _seen: Array[InputEvent] = []
var _made: Array[InputEvent] = []
var _presses := 0


func before_each() -> void:
	layer = get_tree().root.get_node_or_null("PadControls")
	assert_not_null(layer, "the autoload is in the tree")
	_xform = get_tree().root.get_final_transform()
	_saved = Settings.get_value(PadControls.KEY, null) \
		if Settings.has_value(PadControls.KEY) else null
	Settings.clear_value(PadControls.KEY)
	layer.apply_settings()
	_seen.clear()
	_made.clear()
	_presses = 0
	layer.synthesized.connect(_on_made)


func after_each() -> void:
	layer.synthesized.disconnect(_on_made)
	if _saved == null:
		Settings.clear_value(PadControls.KEY)
	else:
		Settings.set_value(PadControls.KEY, _saved)
	layer.apply_settings()
	get_viewport().gui_release_focus()
	await get_tree().process_frame


func _on_made(event: InputEvent) -> void:
	_made.append(event)


# ------------------------------------------------------------- helpers --

## The 1280x800 the screens are laid out for, on a layer of its own,
## above the runner's panel. The table itself can hold the focus, so a
## wake that follows the focus lands at its centre, (640, 400).
func _build_stage() -> void:
	_stage = CanvasLayer.new()
	_stage.layer = 200
	add_child_autofree(_stage)
	_table = Control.new()
	_table.size = Vector2(1280, 800)
	_table.focus_mode = Control.FOCUS_ALL
	_stage.add_child(_table)


func _add_button(text: String, at: Vector2, size := Vector2(120, 40)) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = size
	button.gui_input.connect(func(ev: InputEvent) -> void: _seen.append(ev))
	button.pressed.connect(func() -> void: _presses += 1)
	_table.add_child(button)
	return button


## A table with one button under its centre, the button holding the
## focus — where the first pad touch wakes the arrow.
func _build_table() -> void:
	_build_stage()
	_button = _add_button("hit me", Vector2(580, 380))
	_button.grab_focus()


func _pad(button: int, pressed: bool, device := 0) -> void:
	var jb := InputEventJoypadButton.new()
	jb.device = device
	jb.button_index = button
	jb.pressed = pressed
	Input.parse_input_event(jb)


func _tilt(axis: int, value: float) -> void:
	var jm := InputEventJoypadMotion.new()
	jm.device = 0
	jm.axis = axis
	jm.axis_value = value
	Input.parse_input_event(jm)


func _mouse_move(at: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = _xform * at
	mm.global_position = mm.position
	mm.device = 0           # a real pointer
	Input.parse_input_event(mm)


## A real mouse button — a trackpad's click, or Steam's copy of a pad
## button — at [param at], the stage's own coordinates.
func _mouse_button(button: int, pressed: bool, at: Vector2) -> void:
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


func _near(got: Vector2, want: Vector2, text := "") -> void:
	assert_true(got.distance_to(want) < 0.01, "%s is %s: %s" % [got, want, text])


## What falls through every layer: the duel's own buttons arrive here.
class Catcher extends Node:
	var caught: Array[int] = []

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventJoypadButton and event.pressed:
			caught.append(event.button_index)


# ====================================================== inert unless asked (1) ==

func test_the_key_reads_auto_until_asked_otherwise() -> void:
	assert_eq(PadControls.KEY, "pad_pointer")
	assert_eq(Settings.pad_pointer(), "auto")
	assert_false(Settings.has_value(PadControls.KEY), "nothing materialized into the file")
	Settings.set_value(PadControls.KEY, "sideways", false)
	assert_eq(Settings.pad_pointer(), "auto", "a value that is not one of the three is auto")
	Settings.clear_value(PadControls.KEY)


func test_auto_follows_the_hardware() -> void:
	var pads := Input.get_connected_joypads()
	assert_eq(PadControls.should_be_active(), not pads.is_empty(),
		"auto is on with a pad plugged in and off without one; here: %s" % [pads])
	assert_eq(layer.is_active(), PadControls.should_be_active())
	assert_eq(layer.is_processing_input(), layer.is_active(), "off: nothing at _input")
	assert_false(layer.is_processing(), "and never a frame until the pad is touched")
	assert_false(layer.is_awake(), "active is not awake")


func test_off_the_pad_reaches_the_layer_not_at_all() -> void:
	layer.choose(PadControls.OFF)
	assert_false(layer.is_active())
	assert_false(layer.is_processing_input())
	_build_table()
	await _settle()
	_pad(JOY_BUTTON_A, true)
	_pad(JOY_BUTTON_A, false)
	await _settle()
	assert_eq(_made.size(), 0, "nothing synthesized")
	assert_false(layer.is_awake())
	# Off, the pad is the engine's: A is `ui_accept`, and the focused
	# button presses itself from it — the keyboard's way.
	assert_eq(_presses, 1, "the engine's own ui_accept pressed the focused button")
	assert_eq(_seen_devices(), [], "and no mouse event ever reached it")


func test_the_duels_own_buttons_pass_through_the_layer() -> void:
	layer.choose(PadControls.ON)
	_build_table()
	var catcher := Catcher.new()
	_stage.add_child(catcher)
	await _settle()
	for button in [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_X, JOY_BUTTON_B, JOY_BUTTON_START,
			JOY_BUTTON_Y, JOY_BUTTON_BACK]:
		_pad(button, true)
		_pad(button, false)
	await _settle()
	assert_eq(catcher.caught, [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_X, JOY_BUTTON_B,
		JOY_BUTTON_START, JOY_BUTTON_Y, JOY_BUTTON_BACK], "every one reached _unhandled_input")
	assert_eq(_made.size(), 0, "and none of them woke the pointer")
	assert_false(layer.is_awake())
	_pad(JOY_BUTTON_A, true)
	_pad(JOY_BUTTON_A, false)
	await _settle()
	assert_eq(catcher.caught.size(), 6, "A is the layer's: it never fell through")
	assert_eq(Controls.pad_text("duel_space"), "RB",
		"and RB, not A, is the one button that advances the duel")


func test_a_pull_of_rt_is_the_left_button_with_a_band_under_it() -> void:
	layer.choose(PadControls.ON)
	_build_table()
	await _settle()
	_tilt(JOY_AXIS_TRIGGER_RIGHT, 0.4)
	await _settle()
	assert_false(layer.is_awake(), "a trigger short of TRIGGER_PULL is nothing")
	assert_eq(_made.size(), 0)
	_tilt(JOY_AXIS_TRIGGER_RIGHT, 0.6)
	await _settle()
	assert_true(layer.is_awake(), "pulled past it, the trigger wakes the layer")
	_near(layer.pointer(), Vector2(640, 400), "at the centre of the focused button")
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true]], "and is the left button, held")
	_tilt(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_tilt(JOY_AXIS_TRIGGER_RIGHT, 0.4)
	await _settle()
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true]],
		"the rest of the travel, and a slip back above TRIGGER_LET, is nothing")
	assert_eq(_presses, 0)
	_tilt(JOY_AXIS_TRIGGER_RIGHT, 0.2)
	await _settle()
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_LEFT, false]],
		"let out under TRIGGER_LET: released")
	assert_eq(_presses, 1, "one press of the button, ours")
	assert_eq(_seen_devices(), [PadControls.SYNTH_DEVICE, PadControls.SYNTH_DEVICE])


func test_lt_is_the_right_button() -> void:
	layer.choose(PadControls.ON)
	_build_table()
	await _settle()
	_tilt(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_tilt(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await _settle()
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_RIGHT, true], [MOUSE_BUTTON_RIGHT, false]])
	assert_eq(_presses, 0, "a right click is not a press of the button")
	assert_eq(_seen_devices(), [PadControls.SYNTH_DEVICE, PadControls.SYNTH_DEVICE])


func test_turning_the_layer_off_lets_a_pulled_trigger_go() -> void:
	layer.choose(PadControls.ON)
	_build_table()
	await _settle()
	_tilt(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _settle()
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true]])
	layer.choose(PadControls.OFF)
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_LEFT, false]],
		"off: the held button is released at once")
	layer.choose(PadControls.ON)
	_tilt(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _settle()
	assert_eq(_made_buttons().size(), 2, "and letting the trigger out later sends nothing")


# ============================================================== the map (2) ==

func test_a_is_the_left_button_where_the_focus_is() -> void:
	layer.choose(PadControls.ON)
	_build_table()
	await _settle()
	_pad(JOY_BUTTON_A, true)
	await _settle()
	assert_true(layer.is_awake(), "the first touch of the pad wakes the layer")
	_near(layer.pointer(), Vector2(640, 400), "at the centre of the focused button")
	assert_eq(get_tree().root.gui_get_hovered_control(), _button, "hovered before pressed")
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true]], "held while A is held")
	assert_eq(_presses, 0, "a Button presses on release")
	_pad(JOY_BUTTON_A, false)
	await _settle()
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_LEFT, false]])
	assert_eq(_presses, 1, "ONE press: ours — the engine's ui_accept never saw the A")
	assert_eq(_seen_devices(), [PadControls.SYNTH_DEVICE, PadControls.SYNTH_DEVICE],
		"the button events the control saw were the layer's own")


func test_lb_is_the_right_button() -> void:
	layer.choose(PadControls.ON)
	_build_table()
	await _settle()
	_pad(JOY_BUTTON_LEFT_SHOULDER, true)
	_pad(JOY_BUTTON_LEFT_SHOULDER, false)
	await _settle()
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_RIGHT, true], [MOUSE_BUTTON_RIGHT, false]])
	assert_eq(_presses, 0, "a right click is not a press of the button")
	assert_eq(_seen_devices(), [PadControls.SYNTH_DEVICE, PadControls.SYNTH_DEVICE],
		"and the button's gui_input saw the right click, as it does from a mouse")


func test_two_quick_as_are_a_double_click_and_a_third_is_a_first() -> void:
	layer.choose(PadControls.ON)
	_build_table()
	await _settle()
	for _round in 3:
		_pad(JOY_BUTTON_A, true)
		_pad(JOY_BUTTON_A, false)
		await _settle()
	var doubles := []
	for ev in _made:
		if ev is InputEventMouseButton and ev.pressed:
			doubles.append(ev.double_click)
	assert_eq(doubles, [false, true, false],
		"the second press within %d ms is the double-click; the third starts over"
		% PadControls.DOUBLE_CLICK_MS)
	assert_eq(_presses, 3, "and every one of them is still a click")


func test_the_left_stick_moves_the_pointer_and_a_held_a_drags() -> void:
	layer.choose(PadControls.ON)
	_build_table()
	await _settle()
	_tilt(JOY_AXIS_LEFT_X, 1.0)
	await _settle()
	assert_true(layer.is_awake())
	assert_true(layer.is_processing(), "a frame a frame while the stick is tilted")
	var start := Vector2(640, 400)
	assert_gt(layer.pointer().x, start.x, "moved right")
	assert_eq(layer.pointer().y, start.y, "and only right")
	var motion: InputEventMouseMotion = _made[_made.size() - 1]
	assert_gt(motion.relative.x, 0.0, "as a mouse motion")
	assert_eq(motion.button_mask, 0, "with nothing held")
	await get_tree().create_timer(0.3).timeout
	_tilt(JOY_AXIS_LEFT_X, 0.0)
	await _settle()
	assert_false(layer.is_processing(), "at rest, no frames")
	var rested: Vector2 = layer.pointer()
	assert_gt(rested.x, 700.0, "well off the button by now (%.0f px a second)" % PadControls.SPEED)
	await _settle()
	assert_eq(layer.pointer(), rested, "and no drift")
	_pad(JOY_BUTTON_A, true)
	_tilt(JOY_AXIS_LEFT_Y, 1.0)
	await _settle()
	var drag: InputEventMouseMotion = _made[_made.size() - 1]
	assert_eq(drag.button_mask, MOUSE_BUTTON_MASK_LEFT, "a stick under a held A is a drag")
	assert_gt(layer.pointer().y, rested.y, "downwards")
	_tilt(JOY_AXIS_LEFT_Y, 0.0)
	_pad(JOY_BUTTON_A, false)
	await _settle()
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_LEFT, false]])
	assert_eq(_presses, 0, "pressed and let go off the button: no press — as under a mouse")


func test_the_pointer_stays_inside_the_window() -> void:
	layer.choose(PadControls.ON)
	_build_table()
	await _settle()
	_tilt(JOY_AXIS_LEFT_X, -1.0)
	await get_tree().create_timer(1.2).timeout
	_tilt(JOY_AXIS_LEFT_X, 0.0)
	await _settle()
	assert_eq(layer.pointer().x, get_viewport().get_visible_rect().position.x,
		"pinned to the left edge, never beyond")


func test_the_right_stick_is_the_wheel_at_the_pointer() -> void:
	layer.choose(PadControls.ON)
	_build_stage()
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(540, 300)
	scroll.size = Vector2(200, 200)
	var tall := Control.new()
	tall.custom_minimum_size = Vector2(180, 2000)
	scroll.add_child(tall)
	_table.add_child(scroll)
	_table.grab_focus()
	await _settle()
	_tilt(JOY_AXIS_RIGHT_Y, 1.0)
	await get_tree().create_timer(0.4).timeout
	_tilt(JOY_AXIS_RIGHT_Y, 0.0)
	await _settle()
	var buttons := _made_buttons()
	assert_gt(buttons.size(), 1, "notches were spent")
	for i in buttons.size():
		assert_eq(buttons[i], [MOUSE_BUTTON_WHEEL_DOWN, i % 2 == 0],
			"a press and a release a notch, down for a stick pushed forward")
	assert_gt(scroll.scroll_vertical, 0, "and the scroller under the pointer scrolled")
	_tilt(JOY_AXIS_RIGHT_Y, -1.0)
	await get_tree().create_timer(0.2).timeout
	_tilt(JOY_AXIS_RIGHT_Y, 0.0)
	await _settle()
	var last: InputEventMouseButton = _made[_made.size() - 1]
	assert_eq(last.button_index, MOUSE_BUTTON_WHEEL_UP, "pulled back: up")


func test_the_dpad_hops_to_the_nearest_button_ahead() -> void:
	layer.choose(PadControls.ON)
	_build_stage()
	var right := _add_button("right", Vector2(1000, 380))
	var far := _add_button("far right", Vector2(1140, 380))
	var down := _add_button("down", Vector2(940, 700))
	_table.grab_focus()
	await _settle()
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	await _settle()
	_near(layer.pointer(), Vector2(1060, 400), "the nearer of the two to the right")
	assert_eq(get_tree().root.gui_get_hovered_control(), right, "and hovered — the preview docks")
	assert_eq(_made_buttons(), [], "a hop clicks nothing")
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	await _settle()
	_near(layer.pointer(), Vector2(1200, 400), "the next")
	assert_eq(get_tree().root.gui_get_hovered_control(), far)
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	await _settle()
	_near(layer.pointer(), Vector2(1200, 400),
		"nothing further right: the pointer stays (the runner's panel below is not \"right\")")
	_pad(JOY_BUTTON_DPAD_DOWN, true)
	_pad(JOY_BUTTON_DPAD_DOWN, false)
	await _settle()
	_near(layer.pointer(), Vector2(1000, 720), "off the line, but below and nearest")
	assert_eq(get_tree().root.gui_get_hovered_control(), down)
	_pad(JOY_BUTTON_A, true)
	_pad(JOY_BUTTON_A, false)
	await _settle()
	assert_eq(_presses, 1, "and A presses what the hop landed on")


func test_a_hop_passes_over_what_is_covered() -> void:
	layer.choose(PadControls.ON)
	_build_stage()
	_add_button("covered", Vector2(1000, 380))
	var far := _add_button("far right", Vector2(1140, 380))
	var veil := Panel.new()
	veil.position = Vector2(980, 360)
	veil.size = Vector2(160, 80)
	_table.add_child(veil)      # after the button: drawn over it
	_table.grab_focus()
	await _settle()
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	await _settle()
	_near(layer.pointer(), Vector2(1200, 400),
		"the nearer button is under a panel, so the hop takes the next one")
	assert_eq(get_tree().root.gui_get_hovered_control(), far)


func test_a_line_scrolled_out_of_view_is_no_target() -> void:
	layer.choose(PadControls.ON)
	_build_stage()
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(900, 100)
	scroll.size = Vector2(200, 100)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_table.add_child(scroll)
	var column := VBoxContainer.new()
	scroll.add_child(column)
	var lines: Array[Button] = []
	for i in 16:
		var line := Button.new()
		line.text = "line %d" % (i + 1)
		line.custom_minimum_size = Vector2(180, 30)
		line.gui_input.connect(func(ev: InputEvent) -> void: _seen.append(ev))
		column.add_child(line)
		lines.append(line)
	var far := _add_button("far right", Vector2(1140, 380))
	_table.grab_focus()
	await _settle()
	# From the table's centre (640, 400), RIGHT: the scroll shows lines 1
	# to 3 up at y 100; lines 8 to 13 would sit dead ahead around y 400
	# — the six nearest of all, SNAP_TRIES of them — but the scroll has
	# them out of view. Without the clip the hop would try those six,
	# every one not drawn, and stay put; with it the far button is what
	# is ahead.
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	await _settle()
	_near(layer.pointer(), Vector2(1200, 400), "the far button, past the scrolled-away lines")
	assert_eq(get_tree().root.gui_get_hovered_control(), far)
	scroll.scroll_vertical = 100000
	await _settle()
	var targets: Array = layer._targets(get_tree().root, get_viewport().get_visible_rect())
	assert_true(targets.has(lines[15]), "scrolled to the foot, line 16 is a target")
	assert_false(targets.has(lines[0]), "and line 1 is not")


func test_a_hidden_or_disabled_button_is_no_target() -> void:
	layer.choose(PadControls.ON)
	_build_stage()
	var hidden := _add_button("hidden", Vector2(900, 380))
	hidden.visible = false
	var off := _add_button("disabled", Vector2(1000, 380))
	off.disabled = true
	var far := _add_button("far right", Vector2(1140, 380))
	_table.grab_focus()
	await _settle()
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	await _settle()
	assert_eq(get_tree().root.gui_get_hovered_control(), far)


## The hand stack the way [CardPile] lays one out: holders stepped 17 px
## down the title edge, each drawn over the one before, so every card
## but the last shows only its top band. The 2026-09-28 report: *"up/down
## on your handheld stack should select various cards you are holding in
## the stack one after another. Left right again move away from the
## stack"* — and before this, UP from the last card found every band's
## centre under the next card and stayed put.
func test_a_hop_walks_a_stepped_pile_band_by_band() -> void:
	layer.choose(PadControls.ON)
	_build_stage()
	var rows: Array[Button] = []
	for i in 5:
		var row := _add_button("card %d" % (i + 1), Vector2(1000, 300 + 17 * i), Vector2(120, 100))
		row.z_index = i
		rows.append(row)
	var beside := _add_button("beside", Vector2(700, 380))
	_table.grab_focus()
	await _settle()
	# From the table's centre: RIGHT is the button beside the pile, RIGHT
	# again the pile — its last card, the one shown whole.
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	await _settle()
	assert_eq(get_tree().root.gui_get_hovered_control(), beside)
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	await _settle()
	assert_eq(get_tree().root.gui_get_hovered_control(), rows[4], "the whole card")
	_near(layer.pointer(), Vector2(1060, 418), "at its centre")
	# UP walks the bands one card at a time, landing on each band's middle.
	for i in [3, 2, 1, 0]:
		_pad(JOY_BUTTON_DPAD_UP, true)
		_pad(JOY_BUTTON_DPAD_UP, false)
		await _settle()
		assert_eq(get_tree().root.gui_get_hovered_control(), rows[i], "UP: card %d" % (i + 1))
		_near(layer.pointer(), Vector2(1060, 300 + 17 * i + 8.5), "on the band of card %d" % (i + 1))
	_pad(JOY_BUTTON_DPAD_UP, true)
	_pad(JOY_BUTTON_DPAD_UP, false)
	await _settle()
	assert_eq(get_tree().root.gui_get_hovered_control(), rows[0], "nothing above the first: stays")
	# DOWN walks back, and LEFT leaves the pile: the bands stand straight
	# above and below, never "left".
	_pad(JOY_BUTTON_DPAD_DOWN, true)
	_pad(JOY_BUTTON_DPAD_DOWN, false)
	await _settle()
	assert_eq(get_tree().root.gui_get_hovered_control(), rows[1], "DOWN: card 2")
	_pad(JOY_BUTTON_DPAD_LEFT, true)
	_pad(JOY_BUTTON_DPAD_LEFT, false)
	await _settle()
	assert_eq(get_tree().root.gui_get_hovered_control(), beside, "LEFT: off the pile")
	assert_eq(_made_buttons(), [], "a hop clicks nothing")


## The graveyard and exile plates are TextureRects with a click of their
## own, marked `pad_target` in the duel; the mark is what makes them a
## hop's business.
func test_a_control_marked_pad_target_is_a_hop_target() -> void:
	layer.choose(PadControls.ON)
	_build_stage()
	var plate := TextureRect.new()
	plate.position = Vector2(1000, 380)
	plate.size = Vector2(40, 60)
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	_table.add_child(plate)
	var far := _add_button("far right", Vector2(1140, 380))
	_table.grab_focus()
	await _settle()
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	await _settle()
	assert_eq(get_tree().root.gui_get_hovered_control(), far, "unmarked, the plate is passed over")
	plate.set_meta(PadControls.TARGET_META, true)
	_pad(JOY_BUTTON_DPAD_LEFT, true)
	_pad(JOY_BUTTON_DPAD_LEFT, false)
	await _settle()
	assert_eq(get_tree().root.gui_get_hovered_control(), plate, "marked, it is the target")
	_near(layer.pointer(), Vector2(1020, 410))


# ===================================================== awake and asleep (3) ==

func test_a_real_mouse_puts_the_layer_to_sleep_and_takes_the_pointer() -> void:
	layer.choose(PadControls.ON)
	_build_table()
	await _settle()
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	await _settle()
	assert_true(layer.is_awake())
	assert_true(layer._arrow.visible, "the arrow is drawn")
	_mouse_move(Vector2(300, 300))
	await _settle()
	assert_false(layer.is_awake(), "a real motion: the mouse has the pointer")
	assert_false(layer._arrow.visible)
	_near(layer.pointer(), Vector2(300, 300), "and the layer's pointer followed it")
	get_viewport().gui_release_focus()
	_pad(JOY_BUTTON_A, true)
	_pad(JOY_BUTTON_A, false)
	await _settle()
	assert_true(layer.is_awake(), "the pad again: awake again")
	_near(layer.pointer(), Vector2(300, 300), "where the mouse last was, with nothing focused")
	assert_eq(_presses, 0, "the click landed there, off the button")


func test_a_trigger_clicks_where_the_trackpad_put_the_pointer() -> void:
	# The Deck: the right trackpad is the OS mouse and moves it onto a
	# card; RT under the same hand clicks THAT card, focus or no focus.
	layer.choose(PadControls.ON)
	_build_table()
	var other := _add_button("other", Vector2(240, 280))
	await _settle()
	assert_eq(get_viewport().gui_get_focus_owner(), _button, "the focus sits on the first button")
	_mouse_move(Vector2(300, 300))
	await _settle()
	_tilt(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_tilt(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _settle()
	assert_true(layer.is_awake())
	_near(layer.pointer(), Vector2(300, 300), "where the trackpad left the mouse, not the focus")
	assert_eq(_presses, 1, "the click landed on the button under the mouse")
	assert_eq(get_tree().root.gui_get_hovered_control(), other)
	# The pad has the pointer now: the next wake after a sleep with no
	# mouse motion between goes back to the focus.
	_mouse_move(Vector2(300, 300))
	await _settle()
	assert_false(layer.is_awake())
	get_viewport().gui_release_focus()
	_button.grab_focus()
	layer._mouse_fresh = false
	_pad(JOY_BUTTON_A, true)
	_pad(JOY_BUTTON_A, false)
	await _settle()
	_near(layer.pointer(), Vector2(640, 400), "no fresh mouse: the focus, as before")


func test_the_wake_never_touches_the_os_pointer_headless() -> void:
	# On a screen the OS pointer is hidden while the arrow is up and
	# shown when it goes; headless there is none to hide.
	layer.choose(PadControls.ON)
	_build_table()
	await _settle()
	var before := Input.mouse_mode
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	await _settle()
	assert_eq(Input.mouse_mode, before)
	_mouse_move(Vector2(300, 300))
	await _settle()
	assert_eq(Input.mouse_mode, before)


func test_turning_the_layer_off_lets_a_held_button_go() -> void:
	layer.choose(PadControls.ON)
	_build_table()
	await _settle()
	_pad(JOY_BUTTON_A, true)
	_pad(JOY_BUTTON_LEFT_SHOULDER, true)
	await _settle()
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_RIGHT, true]], "held")
	layer.choose(PadControls.OFF)
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_RIGHT, true],
		[MOUSE_BUTTON_LEFT, false], [MOUSE_BUTTON_RIGHT, false]],
		"released where the pointer was, so no screen is left holding them")
	assert_false(layer.is_awake())
	assert_false(layer._arrow.visible)
	_pad(JOY_BUTTON_A, false)
	_pad(JOY_BUTTON_LEFT_SHOULDER, false)
	await _settle()
	assert_eq(_made_buttons().size(), 4, "the pad's own releases, arriving later, are nobody's")


func test_a_release_with_nothing_held_sends_nothing() -> void:
	layer.choose(PadControls.ON)
	_build_table()
	await _settle()
	_pad(JOY_BUTTON_A, false)
	await _settle()
	assert_eq(_made_buttons(), [], "a stray release — the press was the engine's, before the switch")


# ================================================ one press is one press (6) ==

## Steam Input sending a mouse click beside pad A — the way the first
## playtest's layout sent Escape beside B — opened a pile with one copy
## and closed it with the other: *"when i click on the graveyard it just
## flashes"*. Either order, the two are one press on the button.
func test_a_mouse_press_doubling_the_pads_own_is_one_press() -> void:
	layer.choose(PadControls.ON)
	_build_table()
	await _settle()
	# The pad first: its press lands; the real one within DOUBLED_MS is
	# eaten, and the real release that answers it too.
	_pad(JOY_BUTTON_A, true)
	await _settle()
	_mouse_button(MOUSE_BUTTON_LEFT, true, Vector2(640, 400))
	await _settle()
	assert_eq(_seen_devices(), [PadControls.SYNTH_DEVICE], "one press reached the button: the pad's")
	assert_true(layer.is_awake(), "and the eaten click did not wake the mouse")
	_mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(640, 400))
	_pad(JOY_BUTTON_A, false)
	await _settle()
	assert_eq(_seen_devices(), [PadControls.SYNTH_DEVICE, PadControls.SYNTH_DEVICE],
		"the pad's release, not the mouse's")
	assert_eq(_presses, 1)
	# The mouse first: the real press lands and takes the pointer; the
	# pad's own, a frame later, is skipped — and so is its release.
	_seen.clear()
	_mouse_button(MOUSE_BUTTON_LEFT, true, Vector2(640, 400))
	_pad(JOY_BUTTON_A, true)
	await _settle()
	assert_eq(_seen_devices(), [0], "one press reached the button: the mouse's")
	assert_false(layer.is_awake(), "the mouse has the pointer")
	_mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(640, 400))
	_pad(JOY_BUTTON_A, false)
	await _settle()
	assert_eq(_seen_devices(), [0, 0])
	assert_eq(_presses, 2)
	# Apart by more than DOUBLED_MS they are two presses, as they should be.
	_seen.clear()
	_pad(JOY_BUTTON_A, true)
	_pad(JOY_BUTTON_A, false)
	await _settle()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 <= PadControls.DOUBLED_MS + 20:
		await get_tree().process_frame      # wall-clock ms, the layer's own clock
	_mouse_button(MOUSE_BUTTON_LEFT, true, Vector2(640, 400))
	_mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(640, 400))
	await _settle()
	assert_eq(_seen_devices(), [PadControls.SYNTH_DEVICE, PadControls.SYNTH_DEVICE, 0, 0])
	assert_eq(_presses, 4)


## Two pads reporting one press — Steam's virtual pad beside the Deck's
## own — is one press, and one hop.
func test_a_second_pad_reporting_the_same_button_is_not_a_second_press() -> void:
	layer.choose(PadControls.ON)
	_build_table()
	var right := _add_button("right", Vector2(1000, 380))
	_add_button("far right", Vector2(1140, 380))
	await _settle()
	_pad(JOY_BUTTON_A, true)
	_pad(JOY_BUTTON_A, true, 1)
	await _settle()
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true]], "one press")
	_pad(JOY_BUTTON_A, false)
	_pad(JOY_BUTTON_A, false, 1)
	await _settle()
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_LEFT, false]], "one release")
	assert_eq(_presses, 1)
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	_pad(JOY_BUTTON_DPAD_RIGHT, true, 1)
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	_pad(JOY_BUTTON_DPAD_RIGHT, false, 1)
	await _settle()
	assert_eq(get_tree().root.gui_get_hovered_control(), right, "one hop, not two")


# ======================================================= the mini-menu (4) ==

func test_a_mini_menu_takes_the_pad_itself_while_it_is_open() -> void:
	layer.choose(PadControls.ON)
	_build_table()
	var menu := PopupMenu.new()
	menu.add_item("First", 11)
	menu.add_item("Second", 22)
	var chosen := []
	menu.id_pressed.connect(func(id: int) -> void: chosen.append(id))
	_table.add_child(menu)
	await _settle()
	menu.position = Vector2i(400, 300)
	menu.popup()
	await _settle()
	_pad(JOY_BUTTON_DPAD_DOWN, true)
	_pad(JOY_BUTTON_DPAD_DOWN, false)
	await _settle()
	_pad(JOY_BUTTON_A, true)
	_pad(JOY_BUTTON_A, false)
	await _settle()
	assert_eq(chosen, [11], "the D-pad walked the menu and A chose — the engine's own way")
	assert_eq(_made.size(), 0, "the layer saw none of it")
	assert_false(layer.is_awake())
	assert_false(menu.visible, "and the menu closed on the choice")


## 2026-09-29: an [OptionButton] opens its menu on the PRESS, so the A
## that opens the Magic Battle deck list hands the menu the pad while A
## is still down — the A up goes to the menu and never reaches the
## layer. Left unnoticed, the layer held A down for good: the next A
## read as a second copy of a press still down, and was dropped.
func test_the_a_that_opens_a_menu_is_let_go_when_the_menu_takes_it() -> void:
	layer.choose(PadControls.ON)
	_build_stage()
	var option := OptionButton.new()
	for i in 60:
		option.add_item("Deck %d" % i)
	option.select(2)
	option.position = Vector2(580, 380)
	option.size = Vector2(120, 40)
	var chosen := []
	option.item_selected.connect(func(i: int) -> void: chosen.append(i))
	_table.add_child(option)
	option.grab_focus()
	await _settle()
	var popup := option.get_popup()
	_pad(JOY_BUTTON_A, true)
	await _settle()
	assert_true(popup.visible, "A on the button opened its menu")
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true]])
	_pad(JOY_BUTTON_A, false)
	await _settle()
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true]],
		"the A up went to the menu — the layer never saw it and pushed nothing")
	assert_true(popup.visible, "the menu is still open")
	assert_eq(chosen, [], "and no row was chosen")
	_pad(JOY_BUTTON_DPAD_DOWN, true)
	_pad(JOY_BUTTON_DPAD_DOWN, false)
	await _settle()
	_pad(JOY_BUTTON_A, true)
	_pad(JOY_BUTTON_A, false)
	await _settle()
	assert_eq(chosen, [0], "the D-pad walked the menu and A chose — the engine's own way")
	assert_false(popup.visible)
	_pad(JOY_BUTTON_A, true)
	await _settle()
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_LEFT, true]],
		"the next A is a press again, not a copy of one still down")
	assert_true(popup.visible, "which opens the menu again")
	_pad(JOY_BUTTON_A, false)
	await _settle()
	assert_eq(_made_buttons(), [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_LEFT, true]])


# ============================================================ the switch (5) ==

func test_the_options_row_is_a_view_of_the_key() -> void:
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var row: OptionButton = screen.find_child("PadPointer", true, false)
	assert_not_null(row, "the Display rows carry a Pad pointer choice")
	assert_eq(row.item_count, 3)
	assert_eq(row.selected, 0, "Auto, with nothing stored")
	row.select(1)
	row.item_selected.emit(1)
	assert_eq(Settings.pad_pointer(), "on", "the key follows the row")
	assert_true(layer.is_active(), "and the layer follows the key at once")
	row.select(2)
	row.item_selected.emit(2)
	assert_eq(Settings.pad_pointer(), "off")
	assert_false(layer.is_active())
	Settings.set_value(PadControls.KEY, "on")
	var fresh: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(fresh)
	await get_tree().process_frame
	var again: OptionButton = fresh.find_child("PadPointer", true, false)
	assert_eq(again.selected, 1, "a stored `on` opens the row on On")


func test_the_choice_survives_a_reload_of_the_file() -> void:
	layer.choose(PadControls.ON)
	Settings.reload()
	assert_eq(Settings.pad_pointer(), "on", "the file carries it")


func test_a_pad_arriving_or_leaving_reapplies_auto() -> void:
	assert_false(Settings.has_value(PadControls.KEY))
	layer.set_active(true)
	assert_true(layer.is_active())
	Input.joy_connection_changed.emit(0, false)
	assert_eq(layer.is_active(), PadControls.should_be_active(),
		"the hardware's word, re-read on the signal")
