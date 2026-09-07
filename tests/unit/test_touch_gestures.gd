extends GutTest
## THE GESTURE VOCABULARY — [TouchGestures], the pure recogniser behind
## the `TouchControls` autoload (`[QoL]`, 2026-09-07: *"touch control
## support if enabled/present, for online web export and play via
## mobiles/tablets"*). Each test walks a timeline of fingers with the
## clock in its own hand and reads back the intents, so the whole map in
## the class doc is pinned without a node, a window or a real second.
##
##   1. Tap is a click at the down point; a wobble under the slop is
##      still a tap; two quick taps carry `double`.
##   2. A long press then a lift is a context click, and it comes on the
##      LIFT, not at the mark.
##   3. Past the slop is a drag: start at the origin, moves, an end.
##   4. On something that scrolls, past the slop is a scroll instead.
##   5. Two fingers: a quick tap is a context click at the first; travel
##      is wheel notches, the content following the fingers.
##   6. What it refuses: a lift it never saw pressed, a third finger, a
##      cancel.

var g: TouchGestures


func before_each() -> void:
	g = TouchGestures.new()


func _kinds(intents: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for intent in intents:
		out.append(intent.kind)
	return out


# ================================================================ tap (1) ==

func test_a_tap_is_a_click_at_the_down_point() -> void:
	assert_eq(g.touch(0, Vector2(100, 100), true, 1000), [], "nothing on the way down")
	assert_eq(g.mode(), TouchGestures.Mode.PRESSED)
	var out := g.touch(0, Vector2(104, 103), false, 1120)
	assert_eq(_kinds(out), ["tap"])
	assert_eq(out[0].pos, Vector2(100, 100), "at the point the finger LANDED, not where it left")
	assert_false(out[0].double)
	assert_eq(g.mode(), TouchGestures.Mode.IDLE)
	assert_eq(g.finger_count(), 0)


func test_a_wobble_under_the_slop_is_still_a_tap() -> void:
	g.touch(0, Vector2(100, 100), true, 1000)
	assert_eq(g.drag(0, Vector2(100 + TouchGestures.SLOP - 1, 100), 1050), [],
		"jitter is not a drag")
	assert_eq(g.mode(), TouchGestures.Mode.PRESSED)
	assert_eq(_kinds(g.touch(0, Vector2(105, 100), false, 1100)), ["tap"])


func test_two_quick_taps_in_one_place_are_a_double() -> void:
	g.touch(0, Vector2(100, 100), true, 1000)
	var first := g.touch(0, Vector2(100, 100), false, 1080)
	assert_false(first[0].double)
	g.touch(0, Vector2(110, 105), true, 1200)
	var second := g.touch(0, Vector2(110, 105), false, 1250)
	assert_eq(_kinds(second), ["tap"])
	assert_true(second[0].double, "within DOUBLE_TAP_MS and DOUBLE_TAP_SLOP of the first")
	g.touch(0, Vector2(110, 105), true, 1300)
	var third := g.touch(0, Vector2(110, 105), false, 1350)
	assert_false(third[0].double, "a double spends the chain; the third tap is a first again")


func test_taps_too_far_apart_in_time_or_space_are_singles() -> void:
	g.touch(0, Vector2(100, 100), true, 1000)
	g.touch(0, Vector2(100, 100), false, 1050)
	g.touch(0, Vector2(100, 100), true, 1050 + TouchGestures.DOUBLE_TAP_MS + 1)
	var late := g.touch(0, Vector2(100, 100), false, 1050 + TouchGestures.DOUBLE_TAP_MS + 60)
	assert_false(late[0].double, "too late")
	g.touch(0, Vector2(100, 100), true, 2000)
	g.touch(0, Vector2(100, 100), false, 2050)
	g.touch(0, Vector2(100 + TouchGestures.DOUBLE_TAP_SLOP + 1, 100), true, 2100)
	var far := g.touch(0, Vector2(100 + TouchGestures.DOUBLE_TAP_SLOP + 1, 100), false, 2150)
	assert_false(far[0].double, "too far")


# ========================================================= long press (2) ==

func test_a_long_press_arms_at_the_mark_and_the_lift_is_the_context_click() -> void:
	g.touch(0, Vector2(200, 300), true, 1000)
	assert_eq(g.tick(1000 + TouchGestures.LONG_PRESS_MS - 1), [], "not yet")
	assert_eq(g.mode(), TouchGestures.Mode.PRESSED)
	var armed := g.tick(1000 + TouchGestures.LONG_PRESS_MS)
	assert_eq(_kinds(armed), ["long_press"], "armed at the mark, reported once")
	assert_eq(g.mode(), TouchGestures.Mode.LONG)
	assert_eq(g.tick(2000), [], "and only once")
	var lift := g.touch(0, Vector2(203, 301), false, 2100)
	assert_eq(_kinds(lift), ["context"], "the menu comes on the LIFT (see the class doc for why)")
	assert_eq(lift[0].pos, Vector2(200, 300))
	assert_eq(g.mode(), TouchGestures.Mode.IDLE)


func test_a_lift_before_the_mark_is_a_tap_not_a_menu() -> void:
	g.touch(0, Vector2(200, 300), true, 1000)
	g.tick(1000 + TouchGestures.LONG_PRESS_MS - 50)
	assert_eq(_kinds(g.touch(0, Vector2(200, 300), false, 1000 + TouchGestures.LONG_PRESS_MS - 10)),
		["tap"])


func test_a_long_pressed_finger_that_moves_becomes_a_drag() -> void:
	g.touch(0, Vector2(200, 300), true, 1000)
	g.tick(1500)
	assert_eq(g.mode(), TouchGestures.Mode.LONG)
	var out := g.drag(0, Vector2(240, 300), 1600)
	assert_eq(_kinds(out), ["drag_start"], "nothing was sent at the mark, so nothing is undone")
	assert_eq(_kinds(g.touch(0, Vector2(240, 300), false, 1700)), ["drag_end"],
		"and the lift ends the drag, not a menu")


# =============================================================== drag (3) ==

func test_past_the_slop_is_a_drag_from_the_origin() -> void:
	g.touch(0, Vector2(100, 100), true, 1000)
	var start := g.drag(0, Vector2(120, 100), 1030)
	assert_eq(_kinds(start), ["drag_start"])
	assert_eq(start[0].origin, Vector2(100, 100), "the press goes where the finger landed")
	assert_eq(start[0].pos, Vector2(120, 100))
	assert_eq(g.mode(), TouchGestures.Mode.DRAGGING)
	var move := g.drag(0, Vector2(150, 110), 1060)
	assert_eq(_kinds(move), ["drag_move"])
	assert_eq(move[0].relative, Vector2(30, 10), "relative to the LAST point, as a mouse reports it")
	var end := g.touch(0, Vector2(150, 110), false, 1100)
	assert_eq(_kinds(end), ["drag_end"])
	assert_eq(end[0].pos, Vector2(150, 110))
	assert_eq(g.mode(), TouchGestures.Mode.IDLE)


func test_a_drag_does_not_count_towards_a_double_tap() -> void:
	g.touch(0, Vector2(100, 100), true, 1000)
	g.drag(0, Vector2(140, 100), 1030)
	g.touch(0, Vector2(140, 100), false, 1060)
	g.touch(0, Vector2(140, 100), true, 1100)
	var tap := g.touch(0, Vector2(140, 100), false, 1150)
	assert_eq(_kinds(tap), ["tap"])
	assert_false(tap[0].double)


func test_the_clock_does_not_arm_a_dragging_finger() -> void:
	g.touch(0, Vector2(100, 100), true, 1000)
	g.drag(0, Vector2(140, 100), 1030)
	assert_eq(g.tick(5000), [], "a moving finger is never a long press")


# ============================================================= scroll (4) ==

func test_on_something_that_scrolls_a_drag_is_a_scroll() -> void:
	g.touch(0, Vector2(100, 100), true, 1000, true)
	var out := g.drag(0, Vector2(100, 130), 1030)
	assert_eq(_kinds(out), ["scroll"])
	assert_eq(out[0].relative, Vector2(0, 30), "the whole travel so far, the slop included")
	assert_eq(g.mode(), TouchGestures.Mode.SCROLLING)
	var more := g.drag(0, Vector2(100, 150), 1060)
	assert_eq(_kinds(more), ["scroll"])
	assert_eq(more[0].relative, Vector2(0, 20))
	assert_eq(g.touch(0, Vector2(100, 150), false, 1100), [],
		"no button was ever pressed, so there is nothing to release")


func test_a_tap_on_something_that_scrolls_is_still_a_tap() -> void:
	g.touch(0, Vector2(100, 100), true, 1000, true)
	assert_eq(_kinds(g.touch(0, Vector2(100, 100), false, 1080)), ["tap"])


# ======================================================== two fingers (5) ==

func test_a_quick_two_finger_tap_is_a_context_click_at_the_first_finger() -> void:
	g.touch(0, Vector2(100, 100), true, 1000)
	g.touch(1, Vector2(160, 100), true, 1040)
	assert_eq(g.mode(), TouchGestures.Mode.TWO)
	assert_eq(g.tick(1000 + TouchGestures.LONG_PRESS_MS + 100), [],
		"two fingers down is not a long press")
	var out := g.touch(1, Vector2(160, 100), false, 1200)
	assert_eq(_kinds(out), ["context"], "on the first lift of either finger")
	assert_eq(out[0].pos, Vector2(100, 100), "at the FIRST finger")
	assert_eq(g.touch(0, Vector2(100, 100), false, 1230), [], "the second lift is spent")
	assert_eq(g.mode(), TouchGestures.Mode.IDLE)


func test_the_first_finger_may_lift_first_too() -> void:
	g.touch(0, Vector2(100, 100), true, 1000)
	g.touch(1, Vector2(160, 100), true, 1040)
	var out := g.touch(0, Vector2(100, 100), false, 1200)
	assert_eq(_kinds(out), ["context"])
	assert_eq(out[0].pos, Vector2(100, 100))


func test_two_fingers_held_too_long_are_not_a_tap() -> void:
	g.touch(0, Vector2(100, 100), true, 1000)
	g.touch(1, Vector2(160, 100), true, 1040)
	assert_eq(g.touch(1, Vector2(160, 100), false, 1000 + TouchGestures.TWO_FINGER_MS + 1), [])
	assert_eq(g.touch(0, Vector2(100, 100), false, 1400), [])


func test_two_fingers_travelling_are_wheel_notches_the_content_following() -> void:
	g.touch(0, Vector2(100, 100), true, 1000)
	g.touch(1, Vector2(160, 100), true, 1010)
	assert_eq(g.drag(0, Vector2(100, 110), 1020), [], "under a notch: nothing yet")
	# Both fingers down by 80 px: the midpoint moved 80 = two notches.
	var out := g.drag(1, Vector2(160, 180), 1030)
	out.append_array(g.drag(0, Vector2(100, 180), 1040))
	assert_eq(_kinds(out), ["wheel", "wheel"])
	assert_eq(out[0].button, MOUSE_BUTTON_WHEEL_UP,
		"fingers moving DOWN scroll UP — the content follows the hand")
	assert_eq(out[0].pos, Vector2(130, 145), "at the midpoint of the two")
	var back := g.drag(0, Vector2(100, 100), 1050)
	back.append_array(g.drag(1, Vector2(160, 100), 1060))
	assert_eq(_kinds(back), ["wheel", "wheel"])
	assert_eq(back[0].button, MOUSE_BUTTON_WHEEL_DOWN)
	assert_eq(g.touch(0, Vector2(100, 100), false, 1070), [], "moved: no context click")
	assert_eq(g.touch(1, Vector2(160, 100), false, 1080), [])


func test_sideways_travel_is_the_horizontal_wheel() -> void:
	g.touch(0, Vector2(100, 100), true, 1000)
	g.touch(1, Vector2(100, 160), true, 1010)
	var out := g.drag(0, Vector2(180, 100), 1020)
	out.append_array(g.drag(1, Vector2(180, 160), 1030))
	assert_eq(_kinds(out), ["wheel", "wheel"])
	assert_eq(out[0].button, MOUSE_BUTTON_WHEEL_LEFT, "fingers moving RIGHT scroll LEFT")


func test_a_pinch_that_keeps_its_midpoint_is_not_a_tap() -> void:
	g.touch(0, Vector2(100, 100), true, 1000)
	g.touch(1, Vector2(160, 100), true, 1010)
	g.drag(0, Vector2(80, 100), 1020)
	g.drag(1, Vector2(180, 100), 1030)
	assert_eq(g.touch(0, Vector2(80, 100), false, 1100), [], "the fingers moved, the midpoint did not")


# ============================================================ refusals (6) ==

func test_a_lift_it_never_saw_pressed_is_ignored() -> void:
	# The normal shape of a touch that began on a popup: the popup took
	# the press and handed back only the release.
	assert_eq(g.touch(0, Vector2(100, 100), false, 1000), [])
	assert_eq(g.drag(0, Vector2(120, 100), 1010), [])
	assert_eq(g.mode(), TouchGestures.Mode.IDLE)


func test_a_third_finger_deadens_the_gesture_until_all_are_up() -> void:
	g.touch(0, Vector2(100, 100), true, 1000)
	g.touch(1, Vector2(160, 100), true, 1010)
	g.touch(2, Vector2(220, 100), true, 1020)
	assert_eq(g.mode(), TouchGestures.Mode.DEAD)
	assert_eq(g.touch(1, Vector2(160, 100), false, 1030), [])
	assert_eq(g.touch(0, Vector2(100, 100), false, 1040), [])
	assert_eq(g.mode(), TouchGestures.Mode.DEAD, "one finger still down")
	assert_eq(g.touch(2, Vector2(220, 100), false, 1050), [])
	assert_eq(g.mode(), TouchGestures.Mode.IDLE, "all up: ready again")
	g.touch(0, Vector2(100, 100), true, 1100)
	assert_eq(_kinds(g.touch(0, Vector2(100, 100), false, 1150)), ["tap"])


func test_a_stray_second_finger_does_not_spoil_a_drag() -> void:
	g.touch(0, Vector2(100, 100), true, 1000)
	g.drag(0, Vector2(140, 100), 1030)
	g.touch(1, Vector2(300, 300), true, 1040)
	assert_eq(g.mode(), TouchGestures.Mode.DRAGGING, "the drag goes on")
	assert_eq(_kinds(g.drag(0, Vector2(160, 100), 1050)), ["drag_move"])
	assert_eq(g.drag(1, Vector2(310, 300), 1055), [], "the stray finger moves nothing")
	assert_eq(g.touch(1, Vector2(310, 300), false, 1060), [])
	assert_eq(_kinds(g.touch(0, Vector2(160, 100), false, 1100)), ["drag_end"])


func test_a_cancelled_drag_still_lets_the_button_go() -> void:
	g.touch(0, Vector2(100, 100), true, 1000)
	g.drag(0, Vector2(140, 100), 1030)
	var out := g.cancel(0, Vector2(140, 100), 1050)
	assert_eq(_kinds(out), ["drag_end"], "a press with no release would leave a screen holding it")
	assert_eq(g.mode(), TouchGestures.Mode.IDLE)


func test_a_cancelled_press_is_neither_a_tap_nor_a_menu() -> void:
	g.touch(0, Vector2(100, 100), true, 1000)
	assert_eq(g.cancel(0, Vector2(100, 100), 1050), [])
	g.touch(0, Vector2(100, 100), true, 2000)
	g.tick(2500)
	assert_eq(g.cancel(0, Vector2(100, 100), 2600), [])
	assert_eq(g.mode(), TouchGestures.Mode.IDLE)


func test_reset_forgets_every_finger() -> void:
	g.touch(0, Vector2(100, 100), true, 1000)
	g.touch(1, Vector2(160, 100), true, 1010)
	g.reset()
	assert_eq(g.mode(), TouchGestures.Mode.IDLE)
	assert_eq(g.finger_count(), 0)
	assert_eq(g.touch(0, Vector2(100, 100), false, 1100), [], "a lift after a reset is a stranger")
