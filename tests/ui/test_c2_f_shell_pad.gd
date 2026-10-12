extends GutTest
## THE PAD LAYER ACROSS A PAD THAT LEAVES, AND A RELEASE IT NEVER SAW
## (bug campaign 2026-10-12, findings r2-4 and b1-1's backstop).
##
##  * A pad that disconnects mid-gesture sends no axis-zero and no
##    button-up — Godot only says `joy_connection_changed`. With the layer
##    staying active (`pad_pointer = on`, or a second pad still there) the
##    last stick tilt drove the pointer for ever and a held A stayed a
##    held left button.
##  * A release eaten by a screen before the layer saw it left the layer
##    thinking A was still down; the next A was then dropped as "a second
##    pad's copy". The layer now asks [Input] whether the pad that pressed
##    it still holds it.

var layer: Node
var _stage: CanvasLayer
var _table: Control
var _saved: Variant = null
var _presses := 0


func before_each() -> void:
	layer = get_tree().root.get_node("PadControls")
	_saved = Settings.get_value(PadControls.KEY, null) if Settings.has_value(PadControls.KEY) else null
	Settings.set_value(PadControls.KEY, PadControls.ON, false)
	layer.apply_settings()
	_stage = CanvasLayer.new()
	_stage.layer = 200
	add_child_autofree(_stage)
	_table = Control.new()
	_table.size = Vector2(1280, 800)
	_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_table)
	_presses = 0


func after_each() -> void:
	_tilt(JOY_AXIS_LEFT_X, 0.0)
	await _settle()
	if _saved == null:
		Settings.clear_value(PadControls.KEY)
	else:
		Settings.set_value(PadControls.KEY, _saved, false)
	layer.set_active(false)
	layer.apply_settings()
	await get_tree().process_frame


func _settle(frames := 2) -> void:
	for _i in frames:
		await get_tree().process_frame


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
	mm.position = get_tree().root.get_final_transform() * at
	mm.global_position = mm.position
	mm.device = 0
	Input.parse_input_event(mm)


# ------------------------------------------------------------- r2-4 --

func test_a_stick_held_as_its_pad_leaves_stops_driving_the_pointer() -> void:
	assert_true(layer.is_active(), "pad_pointer=on: active with no pad")
	_tilt(JOY_AXIS_LEFT_X, 1.0)
	await _settle()
	Input.joy_connection_changed.emit(0, false)
	await _settle()
	var before: Vector2 = layer.pointer()
	await _settle(20)
	assert_eq(layer.pointer(), before, "the pointer stops once its pad is gone")
	assert_true(layer.is_active(), "and the layer, set to On, stays on")


func test_a_held_a_as_its_pad_leaves_is_let_go() -> void:
	var made: Array = []
	var on_made := func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			made.append([ev.button_index, ev.pressed])
	layer.synthesized.connect(on_made)
	_pad(JOY_BUTTON_A, true)
	await _settle()
	assert_true(layer._left_held, "A down is the left button held")
	Input.joy_connection_changed.emit(0, false)
	await _settle()
	layer.synthesized.disconnect(on_made)
	assert_false(layer._left_held, "the pad that held it is gone: the left button is released")
	assert_eq(made, [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_LEFT, false]],
		"and the screen under it was told so")


func test_a_pulled_trigger_and_a_turning_wheel_are_forgotten_with_their_pad() -> void:
	var trigger := InputEventJoypadMotion.new()
	trigger.device = 0
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	Input.parse_input_event(trigger)
	_tilt(JOY_AXIS_RIGHT_Y, 1.0)
	await _settle()
	assert_true(layer._trigger_down[JOY_AXIS_TRIGGER_RIGHT])
	Input.joy_connection_changed.emit(0, false)
	await _settle()
	assert_false(layer._trigger_down[JOY_AXIS_TRIGGER_RIGHT], "no trigger is still pulled")
	assert_eq(layer._axes, [0.0, 0.0, 0.0, 0.0] as Array[float], "no stick is still tilted")
	assert_eq(layer._wheel_accum, 0.0)
	assert_false(layer._right_held or layer._left_held)


# ------------------------------------------------- b1-1, the backstop --

func test_an_a_whose_release_never_reached_the_layer_is_a_press_again() -> void:
	var button := Button.new()
	button.text = "after"
	button.position = Vector2(900, 100)
	button.size = Vector2(120, 40)
	button.pressed.connect(func() -> void: _presses += 1)
	_table.add_child(button)
	await _settle()
	# A screen ate A's release before the layer saw it: Input knows the
	# button is up, the layer does not.
	var eater := Eater.new()
	add_child_autofree(eater)
	_pad(JOY_BUTTON_A, true)
	await _settle()
	eater.eat = true
	_pad(JOY_BUTTON_A, false)
	await _settle()
	eater.eat = false
	assert_true(bool(layer._pad_down.get(JOY_BUTTON_A, false)), "control: the layer missed the release")
	_mouse_move(Vector2(960, 120))
	await _settle()
	_pad(JOY_BUTTON_A, true)
	await _settle()
	_pad(JOY_BUTTON_A, false)
	await _settle()
	assert_eq(_presses, 1, "the next A on a button presses it")


func test_a_second_pads_copy_of_a_held_press_is_still_one_press() -> void:
	var made: Array = []
	var on_made := func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			made.append([ev.button_index, ev.pressed])
	layer.synthesized.connect(on_made)
	_pad(JOY_BUTTON_A, true)
	_pad(JOY_BUTTON_A, true, 1)
	await _settle()
	_pad(JOY_BUTTON_A, false)
	_pad(JOY_BUTTON_A, false, 1)
	await _settle()
	layer.synthesized.disconnect(on_made)
	assert_eq(made, [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_LEFT, false]], "one press, one release")


## A node that marks the pad's A handled while [member eat] is set — a
## screen that read the release itself — sitting after the autoloads, so
## it sees the event first.
class Eater extends Node:
	var eat := false

	func _input(event: InputEvent) -> void:
		if eat and event is InputEventJoypadButton:
			get_viewport().set_input_as_handled()
