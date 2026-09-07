extends Node
## THE TOUCH LAYER — autoload `TouchControls`: the one place a finger is
## turned into the mouse the 1997 screens were written for.
##
## `[QoL]`. The original ran in a 640x480 window under a two-button
## mouse; nothing in it knows a touchscreen. This layer is what makes the
## web export playable on a tablet or a phone, and the desktop game
## playable on a touch laptop, WITHOUT any screen learning a new event:
## every context menu, card drag, hover preview and double-click on the
## table keeps its mouse handler, and this node types the mouse for the
## finger. Godot's own `emulate_mouse_from_touch` does half of that
## already (tap is a click, a moving finger is a left drag) and it is
## left ON, because it is also what keeps [Input]'s mouse position under
## the finger for the screens that ask `get_global_mouse_position()`
## while dragging. What it cannot do is the other half: there is no
## right button for the menus, a press lands the click before the preview
## can dock, and a fingertip's wobble turns a tap on a card into a 5-px
## drag of it. So while this layer is ACTIVE it takes the whole touch
## stream at `_input` — the engine's emulated mouse events (`device ==
## DEVICE_ID_EMULATION`) AND the raw [InputEventScreenTouch] /
## [InputEventScreenDrag] behind them — reads the touches into a
## [TouchGestures] recogniser, and pushes mouse events of its own: a
## hover on touch-down, a click on lift, a right click after a long
## press, a proper drag past a wide slop. Real mouse events (`device >=
## 0`, not ours) pass through untouched, so a touch laptop keeps its
## mouse and its trackpad exactly as before.
##
## WHY THE RAW TOUCHES ARE TAKEN TOO. Godot 4.7's [BaseButton] presses
## itself from a bare [InputEventScreenTouch] (measured: `button_down` on
## the touch, `pressed` on its lift, with the emulated mouse swallowed),
## and a [ScrollContainer] scrolls itself from a raw drag on a
## touchscreen. Left alone beside this layer's click, each of those would
## act TWICE — the button once for the touch and once for the mouse — so
## while the layer is active every control sees the finger only as the
## mouse it already understands, and nothing else. What the raw events
## did natively, the layer does on purpose: a one-finger drag that
## begins inside a [ScrollContainer] moves that container's scroll
## values with the finger (see [method _scroll]); everything else that
## reads a wheel — the deck builder's card grid, a log, a list — takes
## two fingers.
##
## WHEN IT IS ACTIVE — one stored value, `touch_controls`, three states,
## on the Options screen's `Display:` rows and in [Settings]:
##
##   - `auto` (the default): active when the platform has a touchscreen
##     ([method DisplayServer.is_touchscreen_available]) or the build is
##     the web one running in a mobile browser (a phone or tablet user
##     agent; `navigator.maxTouchPoints` counts as well). A desktop with
##     a mouse and no touchscreen never turns it on.
##   - `on`: active regardless — a touch laptop whose screen Godot did
##     not report, or the owner testing the layer on the desk.
##   - `off`: never, whatever the hardware.
##
## INERT MEANS INERT. When not active the node processes no input and no
## frame: `set_process_input(false)`, `set_process(false)`, no state,
## nothing pushed. Mouse and keyboard play is then the same stream of
## events it was before this file existed; `tests/ui/test_touch_controls.gd`
## pins that a real mouse click reaches a button with nothing synthesized
## whether the layer is off OR on.
##
## WHY EVERYTHING IS PUSHED FROM `_process` AND NOT FROM `_input`. `_input`
## runs INSIDE the viewport's delivery of the raw touch, and a push from
## there re-enters that delivery — the pushed event's "handled" state
## replaces the touch's, and the GUI's hover and focus bookkeeping runs
## inside itself. The raw touch is instead recorded and marked handled,
## and the recogniser's intents are spent at the top of the next
## `_process`, one frame (at most 16 ms) later, which no hand can feel.
##
## THE FAT FINGER. A tap that lands on nothing that listens — the space
## between two small 1997 buttons, a label beside one — is moved to the
## nearest enabled button within [constant SNAP_RADIUS] (half of the
## 44-px minimum target every mobile guideline asks for), and only if
## that button really is what is drawn there. No layout changes, no
## button grows; the tap is just given the benefit of the doubt. A tap on
## anything that has a handler of its own is left exactly where it fell.
##
## The keyboard is untouched: a tablet has none, and every screen that
## takes keys takes clicks too.

## The [Settings] key and its three values.
const KEY := "touch_controls"
const AUTO := "auto"
const ON := "on"
const OFF := "off"

## The `device` stamped on every event this layer pushes. Godot's own
## finger-as-mouse events carry `DEVICE_ID_EMULATION` (-1) and a real
## pointer a small non-negative id; this is neither, so `_input` can tell
## its own events from both and leave them alone.
const SYNTH_DEVICE := 4096
## Half of the 44-px minimum touch target: how far a tap on nothing may
## be moved to reach the nearest button.
const SNAP_RADIUS := 22.0

## Every event this layer pushes, in order — for tests and for anyone
## curious. Not the raw touches, not the engine's emulation, ours only.
signal synthesized(event: InputEvent)

var _gestures := TouchGestures.new()
var _active := false
## Raw touches recorded at `_input`, spent at `_process` (see the doc).
var _queue: Array[Dictionary] = []
## A synthesized LEFT press is outstanding (a drag is in progress).
var _left_held := false
## Where the last synthesized event put the mouse.
var _pointer := Vector2.ZERO
## The [ScrollContainer] a one-finger scroll began in, and the fraction
## of a pixel the finger has travelled beyond what was applied to it.
var _scroll_node: ScrollContainer = null
var _scroll_accum := Vector2.ZERO


func _ready() -> void:
	set_process_input(false)
	set_process(false)
	apply_settings()


# ------------------------------------------------------------ the switch --

## What the file asks for: `auto`, `on` or `off`.
static func wanted() -> String:
	return Settings.touch_controls()


## Does this platform look like it is played by finger? A touchscreen the
## display server can see, or the web build in a mobile browser.
static func platform_wants_touch() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	if OS.has_feature("web"):
		return _web_is_mobile()
	return false


## The web build's second opinion, for the browsers that report no
## touchscreen until the first touch: the user agent's own word, or the
## touch-point count. Never called off the web.
static func _web_is_mobile() -> bool:
	var agent: Variant = JavaScriptBridge.eval("navigator.userAgent", true)
	if agent is String:
		var re := RegEx.new()
		re.compile("(?i)android|iphone|ipad|ipod|mobile|tablet")
		if re.search(agent) != null:
			return true
	var points: Variant = JavaScriptBridge.eval("navigator.maxTouchPoints", true)
	return points is float and points > 0.0


## The stored setting, resolved against the platform.
static func should_be_active() -> bool:
	match wanted():
		ON:
			return true
		OFF:
			return false
		_:
			return platform_wants_touch()


## Put the stored setting into effect. Idempotent, and silent everywhere
## — a headless run resolves `auto` to off and processes nothing.
func apply_settings() -> void:
	set_active(should_be_active())


## The Options row's own setter: store, then apply — the file and the
## layer cannot disagree.
func choose(mode: String) -> void:
	Settings.set_value(KEY, mode)
	apply_settings()


func is_active() -> bool:
	return _active


func set_active(on: bool) -> void:
	if on == _active:
		return
	if not on:
		_let_go()
		_gestures.reset()
		_queue.clear()
	_active = on
	set_process_input(on)
	set_process(on)


## The recogniser, for tests that want to read its mode.
func gestures() -> TouchGestures:
	return _gestures


# ---------------------------------------------------------------- input --

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			# The engine's finger-as-mouse: replaced by ours, below.
			get_viewport().set_input_as_handled()
		return          # a real mouse, or an event of our own: not ours to touch
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_queue.append({"kind": "touch", "index": st.index, "pos": st.position,
			"pressed": st.pressed, "canceled": st.canceled,
			"ms": Time.get_ticks_msec()})
		get_viewport().set_input_as_handled()   # ours now (class doc)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_queue.append({"kind": "drag", "index": sd.index, "pos": sd.position,
			"ms": Time.get_ticks_msec()})
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	flush()


## Spend everything recorded since the last frame, then the clock. Tests
## call this to skip the frame's wait; the game never needs to.
func flush() -> void:
	var pending := _queue
	_queue = []
	for raw in pending:
		match raw.kind:
			"touch":
				if raw.pressed:
					_hover(raw.pos)
					var container := _scroll_container_under()
					if _gestures.finger_count() == 0:
						_scroll_node = container      # the first finger's is the one
						_scroll_accum = Vector2.ZERO
					_spend(_gestures.touch(raw.index, raw.pos, true, raw.ms,
						container != null))
				elif raw.canceled:
					_spend(_gestures.cancel(raw.index, raw.pos, raw.ms))
				else:
					_spend(_gestures.touch(raw.index, raw.pos, false, raw.ms))
			"drag":
				_spend(_gestures.drag(raw.index, raw.pos, raw.ms))
	_spend(_gestures.tick(Time.get_ticks_msec()))


## Intents into mouse events. Each kind is one line of the gesture map in
## [TouchGestures]; the map is documented there, the events are made here.
func _spend(intents: Array[Dictionary]) -> void:
	for intent in intents:
		match intent.kind:
			"tap":
				var at: Vector2 = _snap(intent.pos)
				_button(MOUSE_BUTTON_LEFT, true, at, intent.double)
				_button(MOUSE_BUTTON_LEFT, false, at, false)
			"context":
				_button(MOUSE_BUTTON_RIGHT, true, intent.pos, false)
				_button(MOUSE_BUTTON_RIGHT, false, intent.pos, false)
			"drag_start":
				_button(MOUSE_BUTTON_LEFT, true, intent.origin, false)
				_left_held = true
				_motion(intent.pos, intent.pos - intent.origin)
			"drag_move":
				_motion(intent.pos, intent.relative)
			"drag_end":
				_motion(intent.pos, intent.pos - _pointer)
				_button(MOUSE_BUTTON_LEFT, false, intent.pos, false)
				_left_held = false
			"scroll":
				_scroll(intent.pos, intent.relative)
			"wheel":
				_wheel(intent.button, intent.pos)
			"long_press":
				pass            # armed; the menu comes on the lift (see TouchGestures)


## A drag interrupted by the switch going off: the button is let go where
## the pointer is, so no screen is left holding a press that never ends.
func _let_go() -> void:
	if _left_held:
		_button(MOUSE_BUTTON_LEFT, false, _pointer, false)
		_left_held = false


# ------------------------------------------------------ event synthesis --

func _push(event: InputEvent) -> void:
	event.device = SYNTH_DEVICE
	get_tree().root.push_input(event, true)
	synthesized.emit(event)


## Where the pointer "is": a plain motion, which is what docks the card
## preview (`mouse_entered`) and what the hover-based lookups read.
func _hover(pos: Vector2) -> void:
	_motion(pos, pos - _pointer)


func _motion(pos: Vector2, relative: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	mm.relative = relative
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT if _left_held else 0
	_pointer = pos
	_push(mm)


func _button(index: int, pressed: bool, pos: Vector2, double: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = index
	mb.pressed = pressed
	mb.double_click = double
	mb.position = pos
	mb.global_position = pos
	if pressed:
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT if index == MOUSE_BUTTON_LEFT \
			else MOUSE_BUTTON_MASK_RIGHT
	_pointer = pos
	_push(mb)


## One wheel notch: a press of the wheel "button" and its release, which
## is the pair a real wheel sends and the pair [ScrollContainer],
## [RichTextLabel] and the deck builder's grid read.
func _wheel(button: int, pos: Vector2) -> void:
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = button
		mb.pressed = pressed
		mb.factor = 1.0
		mb.position = pos
		mb.global_position = pos
		_push(mb)


## A one-finger scroll: the content follows the finger, as it does in
## every phone list. The container's own scroll values are moved (they
## clamp themselves), whole pixels at a time, the fraction carried to
## the next move so a slow finger is not lost to rounding. The pointer
## is moved along too, so the hover follows the finger as it would under
## a mouse. If the container has gone (a screen changed under the
## finger) the rest of the gesture does nothing.
func _scroll(pos: Vector2, relative: Vector2) -> void:
	_motion(pos, relative)
	if not is_instance_valid(_scroll_node) or not _scroll_node.is_inside_tree():
		return
	_scroll_accum += relative
	var step := Vector2i(int(_scroll_accum.x), int(_scroll_accum.y))
	_scroll_accum -= Vector2(step)
	if step.y != 0:
		_scroll_node.scroll_vertical -= step.y
	if step.x != 0:
		_scroll_node.scroll_horizontal -= step.x


# ---------------------------------------------------- what is under it --

## The [ScrollContainer] the hovered control sits in, or null. Read after
## the hover has been pushed, from the viewport's own answer to "what is
## hovered", so it agrees with what a mouse there would be over.
func _scroll_container_under() -> ScrollContainer:
	var node: Control = get_tree().root.gui_get_hovered_control()
	while node != null:
		if node is ScrollContainer:
			return node as ScrollContainer
		node = node.get_parent_control()
	return null


## The fat-finger rule (class doc): a tap on nothing that listens is moved
## to the nearest enabled button within [constant SNAP_RADIUS], provided
## the button is what is really drawn at the new point.
func _snap(pos: Vector2) -> Vector2:
	var root := get_tree().root
	_hover(pos)
	var under: Control = root.gui_get_hovered_control()
	if under != null and not _is_passive(under):
		return pos
	var best: BaseButton = null
	var best_distance := SNAP_RADIUS
	for button in _buttons(root):
		var distance := _distance_to_rect(pos, button.get_global_rect())
		if distance <= best_distance:
			best = button
			best_distance = distance
	if best == null:
		return pos
	var rect := best.get_global_rect().grow(-1.0)
	var target := pos.clamp(rect.position, rect.end)
	_hover(target)
	if root.gui_get_hovered_control() != best:
		_hover(pos)         # something else is drawn over it; the tap stays put
		return pos
	return target


## Does anything from this control up to the first `MOUSE_FILTER_STOP`
## handle a click? Engine widgets that do, a connected `gui_input`, or a
## script that overrides it.
func _is_passive(control: Control) -> bool:
	var node := control
	while node != null:
		if _handles_input(node):
			return false
		if node.mouse_filter == Control.MOUSE_FILTER_STOP:
			return true
		node = node.get_parent_control()
	return true


static func _handles_input(node: Control) -> bool:
	if node is BaseButton or node is Range or node is LineEdit \
			or node is TextEdit or node is ItemList or node is Tree \
			or node is RichTextLabel or node is TabBar \
			or node is ScrollContainer or node is SplitContainer \
			or node is GraphEdit or node is ColorPicker:
		return true
	if node.gui_input.get_connections().size() > 0:
		return true
	return node.get_script() != null and node.has_method("_gui_input")


## Every button a tap could be meant for: visible, enabled, listening.
func _buttons(node: Node) -> Array[BaseButton]:
	var out: Array[BaseButton] = []
	if node is CanvasItem and not (node as CanvasItem).visible:
		return out
	if node is Window and node != get_tree().root and not (node as Window).visible:
		return out
	if node is BaseButton:
		var button := node as BaseButton
		if not button.disabled and button.mouse_filter != Control.MOUSE_FILTER_IGNORE \
				and button.is_visible_in_tree():
			out.append(button)
	for child in node.get_children():
		out.append_array(_buttons(child))
	return out


static func _distance_to_rect(point: Vector2, rect: Rect2) -> float:
	var nearest := point.clamp(rect.position, rect.end)
	return point.distance_to(nearest)
