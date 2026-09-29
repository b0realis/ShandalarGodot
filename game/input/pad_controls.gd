extends Node
## THE PAD LAYER — autoload `PadControls`: the one place a controller is
## turned into the mouse the 1997 screens were written for.
##
## `[QoL]`, the twin of [TouchControls] (2026-09-27, the Steam Deck
## release: *"pad navigable duel"*). The original knew a keyboard and a
## two-button mouse; a pad's buttons reached the duel on 2026-09-18 as
## actions ([Controls]) with the ruling that a pad has no pointer and
## the table is played with a mouse, a finger, or a Steam Deck's
## trackpad. That left a Deck in its GAMEPAD layout — and any pad on a
## desk — unable to pick a card, and it left the shell, the Options and
## the setup screens as mouse-only rooms. So this layer types the mouse
## for the pad, the way the touch layer types it for the finger, and
## every screen keeps its mouse handler: the context menus, the card
## drag, the hover preview, the double-click auto-cast, the sliders,
## the scrollers.
##
## WHAT THE PAD DOES while the layer is active and awake:
##
##   - the LEFT STICK moves a pointer of this layer's own, drawn as an
##     arrow above everything ([constant LAYER]); the OS pointer is
##     hidden meanwhile so there is one arrow on the screen, not two;
##   - the D-PAD hops the pointer to the nearest card or button in
##     that direction ([method _hop]) — the way a console menu walks,
##     but over the whole table, the hand and the Situation Bar alike.
##     It lands on the part of the target that is SEEN ([method _aim],
##     2026-09-28): a hand card under the next in the stack shows only
##     its band, and the band is where the pointer goes — so UP and
##     DOWN walk the stack one card at a time and LEFT and RIGHT leave
##     it, the piles in the Situation Bar are targets too, and *"left
##     does not work"* is no longer a thing the second playtest sees;
##   - [constant CLICK_BUTTON] (A) is the left mouse button — pressed
##     while it is held, so a stick under a held A is a drag, and a
##     second press within [constant DOUBLE_CLICK_MS] is the double-click
##     that auto-casts a hand card;
##   - [constant MENU_BUTTON] (LB) is the right mouse button — the
##     1997 mini-menus on a card, the territory, the life box;
##   - the TRIGGERS are the two mouse buttons again, RT the left and LT
##     the right ([constant TRIGGERS], 2026-09-28) — a trigger pulled
##     past [constant TRIGGER_PULL] is the button down, let out under
##     [constant TRIGGER_LET] it is up, and the band between the two
##     keeps a finger resting on the edge from clicking twice. For the
##     Steam Deck whose right trackpad is the mouse: the trackpad puts
##     the pointer on a card and the trigger under the same hand clicks
##     it, the way the Deck's own desktop works;
##   - the RIGHT STICK is the wheel, [constant WHEEL_RATE] notches a
##     second at full tilt, for the Options panel, the log and the deck
##     builder's grid.
##
## While a mini-menu (a [PopupMenu] — an embedded window) is open, the
## engine forwards the pad to it before this layer sees anything: its
## D-pad walks the entries and A picks one, the way every console menu
## does; the pointer waits. That includes the RELEASE of the very press
## that opened it (2026-09-29): an [OptionButton] opens its menu on the
## press, so an A on the Magic Battle deck list hands the menu the pad
## while A is still down, and the A up never reaches this layer. The
## layer lets that button go itself when its press opened a focused
## window ([method _window_took_press]) — otherwise the next A would be
## read as a second pad's copy of a press still down and be dropped.
##
## ONE PRESS IS ONE PRESS (2026-09-28, the second Steam Deck playtest:
## *"when i click on the graveyard it just flashes"*). Steam Input can
## send a game two copies of one gesture — the first playtest's layout
## sent Escape beside pad B, and a layout that sends a mouse click
## beside A, or a second pad beside the first, opens a pile with one
## copy and closes it with the other. So a real mouse press of a button
## within [constant DOUBLED_MS] of this layer's own press of it is eaten
## (and its release with it), this layer's press within that of a real
## one is skipped, and a pad button already down is not pressed again
## by another device ([member _pad_down]).
##
## Every other button passes through untouched to the duel's own
## actions: B cancels, X is Done, Y the hand, Start the pause menu, Back
## the log, and RB — [Controls] `duel_space`, "the one button" — presses
## whatever the Situation Bar's only button is, which is how a turn is
## advanced with the pad (*"one button dedicated to advance game
## stage"*). A is no longer that button by default: on a pad A is the
## click, on the keyboard Space still is the one button.
##
## WHY THE ENGINE'S OWN FOCUS WALK IS NOT USED for the table. Godot's
## `ui_left/right/up/down` already move a focus ring between [Button]s
## on a D-pad, and every [MiniCard] IS a Button. But a focus is a
## keyboard thing: a focused card answers Space and Enter with a press
## ([BaseButton] and `ui_accept`), which takes the Spacebar rule off the
## table for as long as the ring sits on a card, and a ring has no
## right button, no drag and no wheel. A pointer has all of them and
## costs the keyboard nothing. The focus walk is still what the pad
## drives when this layer is OFF, and what the arrows drive always —
## the shell, the Options, the setup screen and the gauntlet's startup
## window give their first button the focus for exactly that.
##
## WHEN IT IS ACTIVE — one stored value, `pad_pointer`, three states,
## on the Options screen's `Display:` rows and in [Settings]:
##
##   - `auto` (the default): active while a controller is connected
##     ([method Input.get_connected_joypads]), and re-read whenever one
##     arrives or leaves. A desk with no pad never turns it on; a Steam
##     Deck in a keyboard-and-mouse layout shows the game no pad and
##     never turns it on either — Steam Input is the pointer there;
##   - `on`: active regardless;
##   - `off`: never — the pad's buttons still reach the duel's actions,
##     and its D-pad the engine's focus walk.
##
## ACTIVE IS NOT AWAKE. An active layer draws nothing and hides nothing
## until the pad is touched: the first stick, D-pad, trigger, A or LB
## wakes it, the arrow appears where the mouse was if the mouse moved
## since the pad last had the pointer — a Deck's trackpad put it on a
## card, and the trigger must click THAT card — or else where the focus
## is (the shell's first button), or else where the mouse last was; and
## the OS pointer goes. A real mouse motion puts it back to sleep at
## once — the arrow goes, the OS pointer returns — so a desk with an idle
## pad beside the mouse sees nothing of this layer, and a Deck that
## swaps between trackpad and stick has one pointer at a time.
##
## INERT MEANS INERT. Not active: no input processed, no frame, no
## state. Mouse and keyboard play is the stream it was before this file
## existed, and the keyboard is never touched even when active.
##
## WHY EVERYTHING IS PUSHED FROM `_process` AND NOT FROM `_input`: the
## reason [TouchControls] gives. The pad event is recorded at `_input`
## and marked handled — so the engine's `ui_accept` never presses a
## focused button under a pad A, and its focus walk never runs under a
## D-pad while a pointer is what the D-pad moves — and the mouse events
## are pushed at the top of the next `_process`, one frame later.
## Stick and wheel are integrated there from the last axis values seen.

## The [Settings] key and its three values.
const KEY := "pad_pointer"
const AUTO := "auto"
const ON := "on"
const OFF := "off"

## The `device` stamped on every event this layer pushes — like
## [constant TouchControls.SYNTH_DEVICE], neither the engine's emulation
## (-1) nor a real pointer's small id, and not the touch layer's either.
const SYNTH_DEVICE := 4097
## The left mouse button on the pad, and the right.
const CLICK_BUTTON := JOY_BUTTON_A
const MENU_BUTTON := JOY_BUTTON_LEFT_SHOULDER
## The triggers as the same two buttons: RT the left, LT the right.
const TRIGGERS := {
	JOY_AXIS_TRIGGER_RIGHT: MOUSE_BUTTON_LEFT, JOY_AXIS_TRIGGER_LEFT: MOUSE_BUTTON_RIGHT,
}
## A trigger is down once pulled this far, and up again only under this.
const TRIGGER_PULL := 0.5
const TRIGGER_LET := 0.3
## A stick this far from centre is resting.
const DEADZONE := 0.25
## Pointer speed at full tilt, pixels a second, over a squared curve so
## the first quarter of the travel is fine work.
const SPEED := 1100.0
## Wheel notches a second at full tilt of the right stick.
const WHEEL_RATE := 12.0
## A second A within this many milliseconds and pixels is a double-click.
const DOUBLE_CLICK_MS := 300
const DOUBLE_CLICK_SLOP := 12.0
## A real mouse press of a button this close to this layer's own press
## of it is Steam's copy of the same gesture (the duel's own rule for
## its actions, [constant DuelScreen.DOUBLED_MS]).
const DOUBLED_MS := 100
## A control that is a hop target whatever it is — the graveyard and
## exile plates, [TextureRect]s with a click of their own.
const TARGET_META := "pad_target"
## A D-pad hop: how far sideways a target may sit before the cone
## widens with distance, and how many candidates are tried before the
## pointer stays put.
const SNAP_CONE := 160.0
const SNAP_TRIES := 6
## The canvas layer the arrow is drawn on: above the fullscreen card
## reader (100) and the skin's drop veil (128).
const LAYER := 900
## The four D-pad buttons and the way each hops.
const HOPS := {
	JOY_BUTTON_DPAD_UP: Vector2.UP, JOY_BUTTON_DPAD_DOWN: Vector2.DOWN,
	JOY_BUTTON_DPAD_LEFT: Vector2.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2.RIGHT,
}

## Every event this layer pushes, in order — for tests and for anyone
## curious. Ours only.
signal synthesized(event: InputEvent)

var _active := false
var _awake := false
## Where the pointer is, in the viewport's own coordinates.
var _pointer := Vector2.ZERO
## The last value seen on each of the four stick axes.
var _axes: Array[float] = [0.0, 0.0, 0.0, 0.0]
## Pad events recorded at `_input`, spent at `_process` (see the doc).
var _queue: Array[Dictionary] = []
## A synthesized press is outstanding.
var _left_held := false
var _right_held := false
## Which triggers are pulled, by axis.
var _trigger_down := {JOY_AXIS_TRIGGER_RIGHT: false, JOY_AXIS_TRIGGER_LEFT: false}
## The pad buttons of ours that are down, by button index — over every
## device, so a second pad reporting the same press is not a second press.
var _pad_down := {}
## When this layer last pressed each mouse button, and when a real mouse
## last did; and whether the real release of a button is owed to an
## eaten real press.
var _synth_ms := {MOUSE_BUTTON_LEFT: -1000000, MOUSE_BUTTON_RIGHT: -1000000}
var _real_ms := {MOUSE_BUTTON_LEFT: -1000000, MOUSE_BUTTON_RIGHT: -1000000}
var _eat_release := {MOUSE_BUTTON_LEFT: false, MOUSE_BUTTON_RIGHT: false}
## The mouse moved since the pad last had the pointer: the next wake
## is where the mouse is, not where the focus is.
var _mouse_fresh := false
var _last_click_ms := -1000000
var _last_click_pos := Vector2.ZERO
## Fraction of a wheel notch the right stick has earned.
var _wheel_accum := 0.0
var _layer: CanvasLayer = null
var _arrow: Arrow = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	_arrow = Arrow.new()
	_arrow.visible = false
	_layer.add_child(_arrow)
	set_process_input(false)
	set_process(false)
	Input.joy_connection_changed.connect(_on_pads_changed)
	apply_settings()


# ------------------------------------------------------------ the switch --

## What the file asks for: `auto`, `on` or `off`.
static func wanted() -> String:
	return Settings.pad_pointer()


## The stored setting, resolved against the hardware.
static func should_be_active() -> bool:
	match wanted():
		ON:
			return true
		OFF:
			return false
		_:
			return not Input.get_connected_joypads().is_empty()


## Put the stored setting into effect. Idempotent, and silent
## everywhere — a headless run with no pad resolves `auto` to off.
func apply_settings() -> void:
	set_active(should_be_active())


## The Options row's own setter: store, then apply — the file and the
## layer cannot disagree.
func choose(mode: String) -> void:
	Settings.set_value(KEY, mode)
	apply_settings()


func is_active() -> bool:
	return _active


## Awake: the arrow is on the screen and the pad owns the pointer.
func is_awake() -> bool:
	return _awake


## Where the layer's pointer is.
func pointer() -> Vector2:
	return _pointer


func set_active(on: bool) -> void:
	if on == _active:
		return
	if not on:
		_let_go()
		_sleep()
		_queue.clear()
		_axes = [0.0, 0.0, 0.0, 0.0]
		_wheel_accum = 0.0
		for axis in _trigger_down:
			_trigger_down[axis] = false
		_pad_down.clear()
	for button in _eat_release:
		_eat_release[button] = false
		_synth_ms[button] = -1000000
		_real_ms[button] = -1000000
	_mouse_fresh = false
	_active = on
	set_process_input(on)
	set_process(false)          # on demand: `_take` starts it


func _on_pads_changed(device: int, connected: bool) -> void:
	# Named in the log, for a playtest report: which pad Steam Input
	# shows the game says which of its layouts is in force.
	print("pad %d %s: %s" % [device, "connected" if connected else "gone",
		Input.get_joy_name(device) if connected else "-"])
	_pad_down.clear()           # a pad gone mid-press owes no release
	apply_settings()


# ---------------------------------------------------------------- input --

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if event.device == SYNTH_DEVICE:
			return
		if event is InputEventMouseButton and _doubled_real(event as InputEventMouseButton):
			get_viewport().set_input_as_handled()
			return
		# A real pointer moved or clicked: it is the pointer now, and
		# the next wake starts where it left it.
		_pointer = event.position
		_mouse_fresh = true
		_sleep()
		return
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		var ours := jb.button_index == CLICK_BUTTON or jb.button_index == MENU_BUTTON \
			or HOPS.has(jb.button_index)
		if not ours:
			return              # the duel's own buttons: not ours to touch
		if jb.pressed == _pad_down.get(jb.button_index, false):
			_take()             # a second pad's copy of a press, or a release owed nothing
			return
		_pad_down[jb.button_index] = jb.pressed
		if jb.button_index == CLICK_BUTTON:
			_queue.append({"kind": "click", "button": MOUSE_BUTTON_LEFT, "pressed": jb.pressed})
		elif jb.button_index == MENU_BUTTON:
			_queue.append({"kind": "click", "button": MOUSE_BUTTON_RIGHT, "pressed": jb.pressed})
		elif jb.pressed:
			_queue.append({"kind": "hop", "dir": HOPS[jb.button_index]})
		_take()
	elif event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		if TRIGGERS.has(jm.axis):
			_trigger(jm.axis, jm.axis_value)
		elif jm.axis >= JOY_AXIS_LEFT_X and jm.axis <= JOY_AXIS_RIGHT_Y:
			_axes[jm.axis] = jm.axis_value
			_take()


## A trigger crossing [constant TRIGGER_PULL] on the way in is a mouse
## button going down, crossing [constant TRIGGER_LET] on the way out is
## it coming up; the rest of its travel is nothing, and stays nobody's.
func _trigger(axis: int, value: float) -> void:
	var was: bool = _trigger_down[axis]
	var now := value > TRIGGER_LET if was else value >= TRIGGER_PULL
	if now == was:
		return
	_trigger_down[axis] = now
	_queue.append({"kind": "click", "button": TRIGGERS[axis], "pressed": now})
	_take()


## A real mouse button: Steam's copy of a press this layer made within
## [constant DOUBLED_MS] — eaten, and the release that answers it owed
## the same; else a real press of its own, remembered so this layer's
## copy of THAT can be skipped ([method _spend]).
func _doubled_real(mb: InputEventMouseButton) -> bool:
	if not _eat_release.has(mb.button_index):
		return false
	if mb.pressed:
		if Time.get_ticks_msec() - _synth_ms[mb.button_index] <= DOUBLED_MS:
			_synth_ms[mb.button_index] = -1000000     # one copy per press
			_eat_release[mb.button_index] = true
			return true
		_real_ms[mb.button_index] = Time.get_ticks_msec()
		return false
	if _eat_release[mb.button_index]:
		_eat_release[mb.button_index] = false
		return true
	return false


## Ours now: handled, and spent next frame.
func _take() -> void:
	get_viewport().set_input_as_handled()
	set_process(true)


func _process(delta: float) -> void:
	flush(delta)


## Spend everything recorded since the last frame, then the sticks.
## Tests call this to skip the frame's wait; the game never needs to.
func flush(delta := 1.0 / 60.0) -> void:
	var pending := _queue
	_queue = []
	for intent in pending:
		_spend(intent)
	_stick(delta)
	_wheel_stick(delta)
	if _queue.is_empty() and _sticks_rest():
		set_process(false)


func _spend(intent: Dictionary) -> void:
	match String(intent["kind"]):
		"hop":
			_wake()
			_hop(intent["dir"])
		"click":
			var button: int = intent["button"]
			var pressed: bool = intent["pressed"]
			if pressed:
				var now := Time.get_ticks_msec()
				if now - _real_ms[button] <= DOUBLED_MS:
					_real_ms[button] = -1000000        # one copy per press
					return      # the mouse's copy of this press clicked already
				_synth_ms[button] = now
				_wake()
				var double := false
				if button == MOUSE_BUTTON_LEFT:
					double = now - _last_click_ms <= DOUBLE_CLICK_MS \
						and _pointer.distance_to(_last_click_pos) <= DOUBLE_CLICK_SLOP
					# A third press is a fresh first, not another double.
					_last_click_ms = -1000000 if double else now
					_last_click_pos = _pointer
					_left_held = true
				else:
					_right_held = true
				var open := _open_windows()
				_button(button, true, _pointer, double)
				if _window_took_press(open):
					_hand_over(button)
			elif button == MOUSE_BUTTON_LEFT and _left_held:
				_left_held = false
				_button(button, false, _pointer, false)
			elif button == MOUSE_BUTTON_RIGHT and _right_held:
				_right_held = false
				_button(button, false, _pointer, false)


## The left stick: the pointer moves at [constant SPEED] times the
## square of the tilt beyond the deadzone, clamped to the window.
func _stick(delta: float) -> void:
	var tilt := Vector2(_axes[JOY_AXIS_LEFT_X], _axes[JOY_AXIS_LEFT_Y])
	var amount := tilt.length()
	if amount < DEADZONE:
		return
	_wake()
	var eased := (amount - DEADZONE) / (1.0 - DEADZONE)
	var step := tilt.normalized() * eased * eased * SPEED * delta
	var view := get_viewport().get_visible_rect()
	var next := (_pointer + step).clamp(view.position, view.end)
	if next != _pointer:
		_motion(next, next - _pointer)


## The right stick, up and down: the wheel, at the pointer.
func _wheel_stick(delta: float) -> void:
	var tilt: float = _axes[JOY_AXIS_RIGHT_Y]
	if absf(tilt) < DEADZONE:
		_wheel_accum = 0.0
		return
	_wake()
	var eased := (absf(tilt) - DEADZONE) / (1.0 - DEADZONE)
	_wheel_accum += eased * WHEEL_RATE * delta
	var notch := MOUSE_BUTTON_WHEEL_DOWN if tilt > 0.0 else MOUSE_BUTTON_WHEEL_UP
	while _wheel_accum >= 1.0:
		_wheel_accum -= 1.0
		_wheel(notch, _pointer)


func _sticks_rest() -> bool:
	for value in _axes:
		if absf(value) >= DEADZONE:
			return false
	return true


# ------------------------------------------------------- awake / asleep --

## The pad has the pointer: the arrow goes where the mouse left it if
## the mouse moved since the pad last had it, else where the focus is,
## else where the mouse last was; and the OS pointer is hidden.
func _wake() -> void:
	if _awake:
		return
	_awake = true
	var view := get_viewport().get_visible_rect()
	var owner := get_viewport().gui_get_focus_owner()
	if _mouse_fresh and view.has_point(_pointer):
		pass                    # `_input` kept it where the mouse went
	elif owner != null and owner.is_visible_in_tree():
		_pointer = _on_screen(owner).get_center()
	else:
		var mouse := get_viewport().get_mouse_position()
		_pointer = mouse if view.has_point(mouse) else view.get_center()
	_mouse_fresh = false
	_pointer = _pointer.clamp(view.position, view.end)
	_arrow.visible = true
	_arrow.tip = _pointer
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_hover(_pointer)


## The mouse has the pointer again.
func _sleep() -> void:
	if not _awake:
		return
	_awake = false
	_arrow.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Release whatever is held, so a screen never keeps a phantom press.
func _let_go() -> void:
	if _left_held:
		_left_held = false
		_button(MOUSE_BUTTON_LEFT, false, _pointer, false)
	if _right_held:
		_right_held = false
		_button(MOUSE_BUTTON_RIGHT, false, _pointer, false)


# ------------------------------------------------------------- the hop --

## A D-pad press: the pointer moves to the nearest card or button in
## [param dir]. Nearest is measured from the pointer to the target's
## aim — the centre of what is seen of it, [method _aim] — how far along
## the direction, weighted by how far across it — inside a cone that
## starts [constant SNAP_CONE] wide and opens at 45 degrees; with
## nothing in it, a cone twice as wide, so the hand's far corner is
## still "down" from the Situation Bar but what sits beside the pointer
## is never "ahead". What is under the pointer already is no target: a
## hop moves. Each candidate is tried in turn and kept only if it is
## what is really drawn at its aim (a window over the table), read from
## the viewport's own answer to "what is hovered" — the touch layer's
## rule. With nothing reachable the pointer stays where it was.
func _hop(dir: Vector2) -> void:
	var from := _pointer
	var here: Control = get_tree().root.gui_get_hovered_control()
	var in_cone: Array = []
	var ahead: Array = []
	for target in _targets(get_tree().root, get_viewport().get_visible_rect()):
		if target == here or (here != null and target.is_ancestor_of(here)):
			continue
		var centre := _aim(target)
		var offset := centre - from
		var along := offset.dot(dir)
		if along < 1.0:
			continue
		var across := absf(offset.cross(dir))
		if across > 2.0 * along + SNAP_CONE:
			continue
		var entry := [along + 2.0 * across, target, centre]
		ahead.append(entry)
		if across <= along + SNAP_CONE:
			in_cone.append(entry)
	var ranked := in_cone if not in_cone.is_empty() else ahead
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for entry in ranked.slice(0, SNAP_TRIES):
		_hover(entry[2])
		if _is_under(entry[1]):
			return
	_hover(from)


## Every control a hop could land on: a visible, enabled button, slider
## or spin box that listens, or a control marked [constant TARGET_META]
## (the graveyard and exile plates), inside [param clip] — the window, cut down
## by every clipping ancestor on the way, so a line scrolled out of a
## [ScrollContainer] is no target (a window cut to the Deck's screen
## scrolls its body, [method OriginalDialog.keep_on_screen]). An
## embedded [Window] — a mini-menu, a file picker — is not walked: while
## one is open and focused the engine hands it the pad's D-pad and A
## before this layer sees them (`ui_up`, `ui_accept` — the menu walks
## itself), and its controls sit in its own coordinates, not the table's.
func _targets(node: Node, clip: Rect2) -> Array[Control]:
	var out: Array[Control] = []
	if node is CanvasItem and not (node as CanvasItem).visible:
		return out
	if node is Window and node != get_tree().root:
		return out
	if node is Control:
		var control := node as Control
		if control.clip_contents:
			clip = clip.intersection(_on_screen(control))
			if not clip.has_area():
				return out
		if _listens(control) and control.mouse_filter != Control.MOUSE_FILTER_IGNORE \
				and control.is_visible_in_tree() and clip.intersects(_on_screen(control)):
			out.append(control)
	for child in node.get_children():
		out.append_array(_targets(child, clip))
	return out


static func _listens(control: Control) -> bool:
	if control.has_meta(TARGET_META):
		return true
	if control is BaseButton:
		return not (control as BaseButton).disabled
	if control is Slider:
		return (control as Slider).editable
	if control is SpinBox:
		return (control as SpinBox).editable
	return false


## Where [param control] is drawn, in the viewport's own coordinates —
## through its [CanvasLayer]'s transform too, which `get_global_rect`
## leaves out (the test runner's scaled panel is where that shows).
static func _on_screen(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


## Where a hop lands on [param target]: the centre of what is SEEN of it
## — its rect on screen, cut to its clipping ancestors, then cut by every
## sibling drawn over it (a higher `z_index`, or the same and later in
## the tree) that takes the mouse. A hand card under the next in the
## stack ([CardPile], 17 px steps) shows only its top band, and its
## centre is under the next card: aimed there the hop is told "the next
## card" and fails, which is what the second playtest reported as *"left
## does not work"*. Of the four strips an overlapping sibling leaves the
## largest is kept; a target covered whole keeps its plain centre and is
## refused at [method _is_under] as before.
func _aim(target: Control) -> Vector2:
	var whole := _on_screen(target)
	var seen := whole.intersection(_clip_of(target))
	var parent := target.get_parent()
	if parent != null:
		var index := target.get_index()
		for sibling in parent.get_children():
			if sibling == target or not (sibling is Control):
				continue
			var over := sibling as Control
			if not over.is_visible_in_tree() or over.mouse_filter == Control.MOUSE_FILTER_IGNORE:
				continue
			if over.z_index < target.z_index \
					or (over.z_index == target.z_index and over.get_index() < index):
				continue
			seen = _uncovered(seen, _on_screen(over))
			if not seen.has_area():
				break
	return seen.get_center() if seen.has_area() else whole.get_center()


## The window, cut down by every clipping ancestor of [param control] —
## what [method _targets] computes on its way down, for one control.
static func _clip_of(control: Control) -> Rect2:
	var clip := control.get_viewport().get_visible_rect()
	var node := control.get_parent()
	while node != null and not (node is Window):
		if node is Control and (node as Control).clip_contents:
			clip = clip.intersection(_on_screen(node as Control))
		node = node.get_parent()
	return clip


## What [param rect] still shows beside [param cover]: the largest of the
## strips above, below, left and right of the cover; an empty rect when
## the cover takes everything.
static func _uncovered(rect: Rect2, cover: Rect2) -> Rect2:
	if not rect.intersects(cover):
		return rect
	var strips := [
		Rect2(rect.position, Vector2(rect.size.x, cover.position.y - rect.position.y)),
		Rect2(Vector2(rect.position.x, cover.end.y), Vector2(rect.size.x, rect.end.y - cover.end.y)),
		Rect2(rect.position, Vector2(cover.position.x - rect.position.x, rect.size.y)),
		Rect2(Vector2(cover.end.x, rect.position.y), Vector2(rect.end.x - cover.end.x, rect.size.y)),
	]
	var best := Rect2()
	for strip in strips:
		if strip.size.x > 0.0 and strip.size.y > 0.0 and strip.get_area() > best.get_area():
			best = strip
	return best


## Whether [param target] is what the viewport says is under the pointer
## — itself, or a child of its own that draws over it.
func _is_under(target: Control) -> bool:
	var under: Control = get_tree().root.gui_get_hovered_control()
	return under == target or (under != null and target.is_ancestor_of(under))


# ------------------------------------------------------ event synthesis --

func _push(event: InputEvent) -> void:
	event.device = SYNTH_DEVICE
	get_tree().root.push_input(event, true)
	synthesized.emit(event)


## The embedded windows open right now — menus, dialogs, floating panels.
func _open_windows() -> Array:
	return get_tree().root.get_embedded_subwindows()


## Whether the press just pushed opened an embedded window that holds
## the focus now: the engine hands it the pad, release and all (see the
## class doc). [param open_before] is [method _open_windows] read before
## the press. The same reading as [TouchControls]' for the same reason.
func _window_took_press(open_before: Array) -> bool:
	for window in get_tree().root.get_embedded_subwindows():
		if window.has_focus() and not open_before.has(window):
			return true
	return false


## A mouse button whose press opened a window that took the pad: the
## pad's own release will go there too, so the button is up as far as
## this layer is concerned — its next press is a fresh first, not a copy.
func _hand_over(button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		_left_held = false
		_pad_down[CLICK_BUTTON] = false
	else:
		_right_held = false
		_pad_down[MENU_BUTTON] = false


## Where the pointer "is": a plain motion, which is what docks the card
## preview (`mouse_entered`) and what the hover-based lookups read.
func _hover(pos: Vector2) -> void:
	_motion(pos, pos - _pointer)


func _motion(pos: Vector2, relative: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	mm.relative = relative
	mm.button_mask = _mask()
	_pointer = pos
	_arrow.tip = pos
	_push(mm)


func _mask() -> int:
	var mask := 0
	if _left_held:
		mask |= MOUSE_BUTTON_MASK_LEFT
	if _right_held:
		mask |= MOUSE_BUTTON_MASK_RIGHT
	return mask


func _button(index: int, pressed: bool, pos: Vector2, double: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = index
	mb.pressed = pressed
	mb.double_click = double
	mb.position = pos
	mb.global_position = pos
	mb.button_mask = _mask()
	_pointer = pos
	_push(mb)


## One wheel notch: a press of the wheel "button" and its release, the
## pair a real wheel sends.
func _wheel(button: int, pos: Vector2) -> void:
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = button
		mb.pressed = pressed
		mb.factor = 1.0
		mb.position = pos
		mb.global_position = pos
		_push(mb)


# -------------------------------------------------------------- the arrow --

## The pointer's arrow: a white cursor with a black edge, a little
## larger than a desktop's for a 7-inch screen, drawn with its tip at
## [member tip]. Takes no mouse and no focus.
class Arrow extends Control:
	const SHAPE: PackedVector2Array = [
		Vector2(0, 0), Vector2(0, 17), Vector2(4.5, 13), Vector2(8, 20.5),
		Vector2(11, 19), Vector2(7.5, 11.5), Vector2(13, 11.5),
	]
	const SCALE := 1.5

	var tip := Vector2.ZERO:
		set(value):
			tip = value
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var points := PackedVector2Array()
		for point in SHAPE:
			points.append(tip + point * SCALE)
		draw_colored_polygon(points, Color.WHITE)
		var edge := points.duplicate()
		edge.append(points[0])
		draw_polyline(edge, Color.BLACK, 1.5, true)
