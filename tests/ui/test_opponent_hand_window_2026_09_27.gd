extends GutTest
## THE OPPONENT'S HAND WINDOW FLOATS AND DRAGS, 2026-09-27.
##
## The owner, playtesting: *"the enemy hand stack should be movable also
## (in player vs ai or ai vs ai) so it does not occlude anything."*
##
## It was a static plate — `StackHand.title_plate`, a Control carrying the
## nine-patch and the bar label and nothing else — hung in a
## MarginContainer row of the opponent's half, bottom-right, level with
## their creature row: `mouse_filter = IGNORE`, no drag, no corner of its
## own, and 43px of the half spent on it. Now it is the player's OWN
## StackHand wearing the opponent's word and colour: a child of the
## SCREEN, dragged by the middle of its bar, its corner kept in Settings
## "opp_hand_stack_pos" (never the player's "hand_stack_pos"), bar-only
## while the hand is hidden (manual p.114) and a full list once it is
## revealed. A hotseat's and a demo's two-seat windows floated already;
## this pins that they drag too.

const KEYS := ["hand_stack_pos", "opp_hand_stack_pos"]

var screen: DuelScreen
var _had: Dictionary = {}


func before_each() -> void:
	for key in KEYS:
		_had[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)


func after_each() -> void:
	for key in KEYS:
		if _had[key] != null:
			Settings.set_value(key, _had[key])
		else:
			Settings.clear_value(key)


func _boot(config: DuelConfig) -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	# A seat with a computer in it makes `_ready` a coroutine, and a size
	# set before it settles is the size warning; so, once it has.
	await get_tree().process_frame
	screen.size = Vector2(1280, 800)
	await get_tree().process_frame
	await get_tree().process_frame


func _opponent() -> StackHand:
	return screen._hand_rows[0] as StackHand   # [opponent, player]


func _bar_press(hand: StackHand, at: Vector2, pressed: bool, where := Vector2.ZERO) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	ev.global_position = where
	hand._on_title_input(ev)


## Drag the window by the middle of its bar from [param from] to [param to].
func _drag(hand: StackHand, from: Vector2, to: Vector2) -> void:
	var grip := Vector2(hand._title_bg.size.x / 2.0, 8)
	_bar_press(hand, grip, true, from)
	var move := InputEventMouseMotion.new()
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	move.global_position = to
	hand._on_title_input(move)
	_bar_press(hand, grip, false, to)


func test_against_the_computer_the_opponents_hand_is_a_floating_stack_hand() -> void:
	await _boot(DuelConfig.vs_ai_default(AiProfile.wizard()))
	assert_true(screen.hidden_hands.has(1), "the computer's hand is face-down")
	var opp := _opponent()
	assert_not_null(opp, "the opponent's window is a StackHand, not a row")
	assert_false(opp is HotseatHand, "the ordinary one, not the two-seat window")
	assert_eq(opp.get_parent(), screen,
		"a child of the SCREEN, floating over the board like the player's own")
	assert_false(opp.pinned, "and free to drag")
	assert_eq(opp.title_word, DuelScreen.OPPONENT_HAND_WORD)
	assert_eq(opp._title.text, "Opponent (%d)" % screen.game.players[1].hand.size(),
		"the 1997 word and the count, nothing else on the bar")
	assert_true(opp.z_index >= DuelScreen.FREE_LAYER_Z,
		"over the table, so a dragged card never hides it")


func test_a_hidden_hand_is_the_bar_alone_at_its_empty_height() -> void:
	await _boot(DuelConfig.vs_ai_default(AiProfile.wizard()))
	var opp := _opponent()
	assert_true(opp.bar_only_when_hidden)
	assert_eq(opp._pile.get_child_count(), 0,
		"manual p.114: only the title bar, never a row of card backs")
	var empty := StackHand.new()
	add_child_autofree(empty)
	assert_eq(opp.size, empty.custom_minimum_size,
		"literally the size an empty StackHand takes")
	assert_eq(opp._title.text, "Opponent (%d)" % screen.game.players[1].hand.size(),
		"and the count is what the bar is for")


func test_a_revealed_hand_lists_its_cards_under_the_bar() -> void:
	await _boot(DuelConfig.vs_ai_default(AiProfile.wizard()))
	var opp := _opponent()
	screen.game.players[1].hand_revealed = true
	screen._refresh()
	await get_tree().process_frame   # the rebuilt rows' predecessors are freed
	var hand: Array = screen.game.players[1].hand
	assert_eq(opp._pile.get_child_count(), hand.size(),
		"a Glasses of Urza reveal stacks the cards the way the player's own are")
	var faces := 0
	for holder in opp._pile.get_children():
		if CardPile._face_in(holder) != null:
			faces += 1
	assert_eq(faces, hand.size(), "face up, every one")
	assert_eq(opp.preview, screen._card_preview,
		"and a hovered card enlarges in the shared preview")
	screen.game.players[1].hand_revealed = false
	screen._refresh()
	await get_tree().process_frame
	assert_eq(opp._pile.get_child_count(), 0, "hidden again: the bar alone")


func test_it_starts_where_the_old_row_hung_the_plate() -> void:
	# Bottom-right of the opponent's half, level with their creature row,
	# clear of the player's window on the right — so nothing moves until
	# the owner drags it.
	await _boot(DuelConfig.vs_ai_default(AiProfile.wizard()))
	var opp := _opponent()
	assert_eq(opp.position, Settings.opp_hand_stack_pos())
	assert_eq(Settings.opp_hand_stack_pos(), Vector2(918, 351))
	var mine: Control = screen._hand_rows[1]
	if mine is StackHand:
		assert_lt(opp.position.y + opp.size.y, mine.position.y,
			"above the player's own window, not on it")


func test_dragging_the_bar_moves_it_and_keeps_its_own_corner() -> void:
	await _boot(DuelConfig.vs_ai_default(AiProfile.wizard()))
	var opp := _opponent()
	var before := opp.position
	_drag(opp, before + Vector2(70, 12), before + Vector2(70, 12) - Vector2(400, 200))
	assert_eq(opp.position, before - Vector2(400, 200), "the window under the grip")
	assert_true(Settings.has_value("opp_hand_stack_pos"), "the corner persists")
	assert_eq(Settings.get_value("opp_hand_stack_pos", null), opp.position)
	assert_false(Settings.has_value("hand_stack_pos"),
		"and the player's own window's preference is untouched")
	# The next duel opens it where it was left.
	await _boot(DuelConfig.vs_ai_default(AiProfile.wizard()))
	assert_eq(_opponent().position, before - Vector2(400, 200))


func test_a_click_on_the_bar_folds_nothing_it_has_no_list_to_fold() -> void:
	await _boot(DuelConfig.vs_ai_default(AiProfile.wizard()))
	var opp := _opponent()
	var grip := Vector2(opp._title_bg.size.x / 2.0, 8)
	_bar_press(opp, grip, true, opp.global_position + grip)
	_bar_press(opp, grip, false, opp.global_position + grip)
	assert_eq(opp._title.text, "Opponent (%d)" % screen.game.players[1].hand.size(),
		"no [+] marker on a bar with nothing under it")
	assert_eq(opp.size.y, StackHand.TITLE_HEIGHT + StackHand.FOOT)
	assert_false(Settings.has_value("opp_hand_stack_pos"), "a click is not a drag")


func test_the_players_own_window_still_writes_its_own_key() -> void:
	await _boot(DuelConfig.vs_ai_default(AiProfile.wizard()))
	var mine: Control = screen._hand_rows[1]
	if not (mine is StackHand):
		pass_test("the fan hand is set; the stack's key is pinned in test_stack_hand")
		return
	var before: Vector2 = mine.position
	_drag(mine, before + Vector2(70, 12), before + Vector2(70, 12) - Vector2(100, 100))
	assert_eq(Settings.get_value("hand_stack_pos", null), mine.position)
	assert_false(Settings.has_value("opp_hand_stack_pos"))


func test_the_half_no_longer_spends_a_row_on_the_plate() -> void:
	await _boot(DuelConfig.vs_ai_default(AiProfile.wizard()))
	var creatures: Control = screen._field_rows[1][DuelScreen.Row.CREATURES]
	var rows: Node = creatures.get_parent()
	assert_eq(rows.get_child(rows.get_child_count() - 1), creatures,
		"the opponent's creature row is the last thing in their half")
	for child in rows.get_children():
		assert_false(child is MarginContainer, "no plate row")


func test_a_demos_two_seat_windows_drag_as_well() -> void:
	# "(in player vs ai or ai vs ai)". The demo's windows are the two-seat
	# HotseatHand, which the screen unpins; pin that it stays so.
	var config := DuelConfig.demo_default()
	config.rng_seed = 92000
	await _boot(config)
	for pid in 2:
		var hand := screen._hand_rows[1 - pid] as HotseatHand
		assert_not_null(hand, "seat %d's window" % pid)
		assert_false(hand.pinned, "seat %d's window drags" % pid)
		var before: Vector2 = hand.position
		_drag(hand, before + Vector2(70, 12), before + Vector2(70, 12) + Vector2(-60, -30))
		assert_eq(hand.position, before + Vector2(-60, -30), "seat %d moved" % pid)
	for key in KEYS:
		assert_false(Settings.has_value(key), "a seat's window writes no preference")
