class_name TouchGestures
extends RefCounted
## THE GESTURE RECOGNISER — fingers in, intents out, and nothing else.
##
## `[QoL]`. The 1997 game was played with a two-button mouse and nothing
## in its string tables knows a finger; this class exists so the same
## screens can be played from a tablet or a phone's browser without a
## line of them changing. It is a pure state machine: [TouchControls]
## (the autoload) feeds it every raw touch and drag with a timestamp and
## takes back a list of INTENTS — *tap here*, *context menu here*, *drag
## from here to there*, *a wheel notch here* — and turns those into the
## mouse events the screens already understand. Nothing in here touches
## a node, the clock or the input singleton, which is what makes the
## whole vocabulary testable headless with a hand-written timeline
## (`tests/unit/test_touch_gestures.gd`).
##
## THE VOCABULARY, and why each gesture maps where it does. The screens
## have exactly three pointer verbs — the left click (do it), the right
## click (what can I do with it — every context menu in the game) and the
## drag (move it) — plus hover for the docked card preview. A finger has
## to reach all four with no second button and no hovering:
##
##   - **touch-down** is HOVER. The autoload pushes a motion event to the
##     point before anything else, so the preview docks the moment a card
##     is touched, exactly as it does when a mouse passes over it.
##   - **tap** (down and up within [constant SLOP], any duration under a
##     long press) is a LEFT CLICK at the down point. A second tap within
##     [constant DOUBLE_TAP_MS] and [constant DOUBLE_TAP_SLOP] carries
##     `double_click`, which is the hand window's auto-cast.
##   - **long-press** ([constant LONG_PRESS_MS] still) and LIFT is a RIGHT
##     CLICK at the down point — the context menu. It fires on the LIFT,
##     not at the 450 ms mark, and that is measured, not taste: a context
##     menu is an embedded popup that takes the finger's own release
##     before this class ever sees it, and [PopupMenu] activates the item
##     under a LEFT release, so a menu opened under a resting finger would
##     choose its first entry as the finger left. Opened after the lift,
##     it waits for a tap like the mouse's menu waits for a click.
##   - **two-finger tap** is the same RIGHT CLICK at the first finger, for
##     the player who would rather not wait. It fires when the first of
##     the two lifts: Godot's own mouse emulation follows one finger only,
##     so whichever lifts second sends the popup nothing it reads.
##   - **one-finger drag** past [constant SLOP] is a LEFT DRAG: press at
##     the origin, motion, release — the card move, the floating-window
##     title bar, the deck builder's drag-and-drop, the volume slider.
##     A finger that rested long enough to arm the long-press and then
##     moves is a drag too; nothing has been sent yet, so nothing is undone.
##   - a one-finger drag that STARTS ON SOMETHING THAT SCROLLS (the
##     autoload says so with `scrollable`) is a SCROLL intent, not a
##     drag: no button is pressed, and the autoload moves the
##     [ScrollContainer] under it with the finger, the way every phone
##     list moves. Nothing in a scrolling list of this game is dragged.
##   - **two-finger drag** is WHEEL NOTCHES at the midpoint, one per
##     [constant WHEEL_STEP] of travel — the deck builder's card grid, the
##     duel log, any list. The finger moving DOWN scrolls UP (the content
##     follows the finger), which is what every touch surface since 2007
##     has taught the hand.
##
## WHAT IT REFUSES. A release for a finger it never saw pressed is
## ignored — that is the normal shape of a touch that began on a popup,
## which takes the press and hands back only the lift. A third finger,
## or a second one landing mid-drag, DEADENS the gesture until every
## finger is up: better a lost tap than a menu the player did not ask for.
##
## TIME IS AN ARGUMENT. Every call takes `now_ms` and the long-press is
## found by [method tick], so a test can walk a whole gesture in
## milliseconds of its choosing and the autoload can pass whatever clock
## the platform has.

## Movement under this many logical pixels is a still finger: a tap, a
## long-press, or jitter. Godot's own drag-and-drop starts at 10 and the
## duel table's card drag at 5; a fingertip on glass wobbles more than a
## mouse on a desk, so this is wider than both.
const SLOP := 12.0
## A finger held still this long is a long-press (the right click).
## Android's own default is 400-500 ms; iOS's 500. The lower end, because
## the menu only opens on the lift and the wait is felt twice otherwise.
const LONG_PRESS_MS := 450
## Two taps this close in time and space are a double-click.
const DOUBLE_TAP_MS := 300
const DOUBLE_TAP_SLOP := 30.0
## Two fingers down together and the first lifting within this many ms of
## the first landing, neither having moved, are a two-finger tap.
const TWO_FINGER_MS := 300
## Two fingers travelling this far together are one wheel notch.
const WHEEL_STEP := 40.0

enum Mode {
	IDLE,       ## no finger down
	PRESSED,    ## one finger, still, not yet a long-press
	LONG,       ## one finger, still, long-press armed — the lift is a right click
	DRAGGING,   ## one finger past the slop: left button held
	SCROLLING,  ## one finger past the slop on something that scrolls
	TWO,        ## two fingers, neither gesture decided
	DEAD,       ## gesture spent or spoiled; waiting for every finger to lift
}

var _mode: int = Mode.IDLE
## index -> {origin, pos, down_ms, scrollable}
var _fingers: Dictionary = {}
## The finger whose gestures are being read (the first one down).
var _primary := -1
var _last_tap_ms := -1
var _last_tap_pos := Vector2.ZERO
var _two_mid := Vector2.ZERO
var _two_accum := Vector2.ZERO
var _two_moved := false


## The current [enum Mode], for tests and for the autoload's own guard.
func mode() -> int:
	return _mode


## How many fingers this class believes are down.
func finger_count() -> int:
	return _fingers.size()


## A finger landed (`pressed`) or lifted. `scrollable` says whether the
## thing under a landing finger scrolls (see the class doc). Returns the
## intents this event completes, in order; often none.
func touch(index: int, pos: Vector2, pressed: bool, now_ms: int,
		scrollable := false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if pressed:
		_press(index, pos, now_ms, scrollable)
		return out
	if not _fingers.has(index):
		return out          # a release whose press went to a popup
	_release(index, pos, now_ms, out, false)
	return out


## The platform cancelled a touch (Android does, when the system takes
## the gesture). The finger is gone; whatever it was doing ends without
## a tap or a menu, but a held button is still let go.
func cancel(index: int, pos: Vector2, now_ms: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _fingers.has(index):
		return out
	_release(index, pos, now_ms, out, true)
	return out


## A finger moved.
func drag(index: int, pos: Vector2, now_ms: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _fingers.has(index):
		return out
	var finger: Dictionary = _fingers[index]
	var previous: Vector2 = finger.pos
	finger.pos = pos
	match _mode:
		Mode.PRESSED, Mode.LONG:
			if index != _primary:
				return out
			if pos.distance_to(finger.origin) <= SLOP:
				return out
			if finger.scrollable:
				_mode = Mode.SCROLLING
				out.append({"kind": "scroll", "pos": pos,
					"relative": pos - finger.origin})
			else:
				_mode = Mode.DRAGGING
				out.append({"kind": "drag_start", "origin": finger.origin,
					"pos": pos})
		Mode.DRAGGING:
			if index == _primary:
				out.append({"kind": "drag_move", "pos": pos,
					"relative": pos - previous})
		Mode.SCROLLING:
			if index == _primary:
				out.append({"kind": "scroll", "pos": pos,
					"relative": pos - previous})
		Mode.TWO:
			_two_drag(out)
		_:
			pass
	return out


## The clock moved. The only gesture that needs it is the long-press,
## which arms after [constant LONG_PRESS_MS] of stillness and is
## reported once so a screen may show it if it wants to.
func tick(now_ms: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _mode != Mode.PRESSED:
		return out
	var finger: Dictionary = _fingers[_primary]
	if now_ms - int(finger.down_ms) < LONG_PRESS_MS:
		return out
	_mode = Mode.LONG
	out.append({"kind": "long_press", "pos": finger.origin})
	return out


## Forget everything — for the autoload when it is switched off mid-touch.
func reset() -> void:
	_fingers.clear()
	_primary = -1
	_mode = Mode.IDLE
	_two_moved = false


# ------------------------------------------------------------ internals --

func _press(index: int, pos: Vector2, now_ms: int, scrollable: bool) -> void:
	if _fingers.has(index):
		return              # a press for a finger already down: a platform hiccup
	_fingers[index] = {"origin": pos, "pos": pos, "down_ms": now_ms,
		"scrollable": scrollable}
	match _mode:
		Mode.IDLE:
			_primary = index
			_mode = Mode.PRESSED
		Mode.PRESSED, Mode.LONG:
			_mode = Mode.TWO
			_two_mid = _midpoint()
			_two_accum = Vector2.ZERO
			_two_moved = false
		Mode.DRAGGING, Mode.SCROLLING:
			pass                # a stray second finger mid-drag: ignored, the drag goes on
		_:
			_mode = Mode.DEAD   # three fingers: nobody meant anything by it


func _release(index: int, pos: Vector2, now_ms: int, out: Array[Dictionary],
		cancelled: bool) -> void:
	var finger: Dictionary = _fingers[index]
	_fingers.erase(index)
	match _mode:
		Mode.PRESSED:
			if index == _primary and not cancelled:
				var double: bool = _last_tap_ms >= 0 \
					and now_ms - _last_tap_ms <= DOUBLE_TAP_MS \
					and finger.origin.distance_to(_last_tap_pos) <= DOUBLE_TAP_SLOP
				out.append({"kind": "tap", "pos": finger.origin, "double": double})
				# A double resets the chain: a third tap is a first again.
				_last_tap_ms = -1 if double else now_ms
				_last_tap_pos = finger.origin
		Mode.LONG:
			if index == _primary and not cancelled:
				out.append({"kind": "context", "pos": finger.origin})
			_last_tap_ms = -1
		Mode.DRAGGING:
			if index == _primary:
				out.append({"kind": "drag_end", "pos": pos})
			_last_tap_ms = -1
		Mode.SCROLLING:
			_last_tap_ms = -1
		Mode.TWO:
			var first: Dictionary = _fingers[_primary] if _fingers.has(_primary) else finger
			var quick: bool = now_ms - int(first.down_ms) <= TWO_FINGER_MS
			if quick and not _two_moved and not cancelled:
				out.append({"kind": "context", "pos": first.origin})
			_last_tap_ms = -1
		_:
			pass
	if _fingers.is_empty():
		_mode = Mode.IDLE
		_primary = -1
	elif (_mode == Mode.DRAGGING or _mode == Mode.SCROLLING) and index != _primary:
		pass                    # the stray finger left; the drag goes on
	else:
		_mode = Mode.DEAD
		if index == _primary:
			_primary = -1


func _midpoint() -> Vector2:
	var sum := Vector2.ZERO
	for finger in _fingers.values():
		sum += finger.pos
	return sum / maxf(1.0, _fingers.size())


func _two_drag(out: Array[Dictionary]) -> void:
	var mid := _midpoint()
	_two_accum += mid - _two_mid
	_two_mid = mid
	if _two_accum.length() > SLOP:
		_two_moved = true
	for finger in _fingers.values():
		if finger.pos.distance_to(finger.origin) > SLOP:
			_two_moved = true       # a pinch keeps the midpoint still; it is not a tap
	while absf(_two_accum.y) >= WHEEL_STEP:
		var down := _two_accum.y > 0.0
		out.append({"kind": "wheel", "pos": mid,
			"button": MOUSE_BUTTON_WHEEL_UP if down else MOUSE_BUTTON_WHEEL_DOWN})
		_two_accum.y -= WHEEL_STEP if down else -WHEEL_STEP
	while absf(_two_accum.x) >= WHEEL_STEP:
		var right := _two_accum.x > 0.0
		out.append({"kind": "wheel", "pos": mid,
			"button": MOUSE_BUTTON_WHEEL_LEFT if right else MOUSE_BUTTON_WHEEL_RIGHT})
		_two_accum.x -= WHEEL_STEP if right else -WHEEL_STEP
