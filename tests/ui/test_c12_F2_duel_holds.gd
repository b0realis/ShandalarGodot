extends GutTest
## THE DUEL STANDS STILL WHEN IT SHOULD, AND ONLY THEN (the bug campaign
## c12, findings h4-1, h4-3 and h4-8).
##
##  * h4-1 — the Concede question and a held duel's `Quit ...?` did not
##    hold the computer. Pause → Concede (or Exit duel) closed the Pause
##    window first, and its closing refresh armed the computer's dwell,
##    which then played on under the question: a turn went by while the
##    player read it. Now neither question lets the computer act, and the
##    duel goes on when the question goes.
##  * h4-3 — a combat skipped AUTOMATICALLY (the Stop off, nothing able to
##    attack) came to rest in Main 2 as if the player had named it, and
##    the unstopped Main 2 waited for a click every such turn. Now only an
##    order the player gave rests where it arrives.
##  * h4-8 — the splash's five seconds ran on under the Pause window and
##    tossed the coin under it. Now the Pause window holds the countdown
##    and the toss, and neither the coin nor the opening window starts
##    while it is up.

var screen: DuelScreen
var _saved_stops: Variant = null
var _next_id := 93100


## Stands in for the computer's seat and only counts how often it acted.
class CountingSeat:
	extends RefCounted
	var acted := 0

	func act(_game: MtgGame) -> String:
		acted += 1
		return ""


func before_each() -> void:
	_saved_stops = Settings.get_value(PhaseStops.SETTING_KEY, null) \
		if Settings.has_value(PhaseStops.SETTING_KEY) else null


func after_each() -> void:
	if _saved_stops == null:
		Settings.clear_value(PhaseStops.SETTING_KEY)
	else:
		Settings.set_value(PhaseStops.SETTING_KEY, _saved_stops)
	await get_tree().process_frame


## A duel against the computer whose own timer never fires in a test.
func _vs_ai() -> DuelScreen:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 1000.0
	config.rng_seed = 93100
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


## The computer (seat 1) holds priority, and a counting stand-in acts for it.
func _computer_to_act() -> CountingSeat:
	var counting := CountingSeat.new()
	screen._ais[1] = counting
	screen.game.priority_player = 1
	screen._ai_pending = false
	return counting


# ============================================== h4-1: the questions hold --

func test_pause_then_concede_holds_the_computer_until_cancel() -> void:
	await _vs_ai()
	var counting := _computer_to_act()
	screen._open_pause()
	screen._on_pause_chosen(DuelPause.Action.CONCEDE)
	assert_not_null(screen._concede_dialog, "control: the question is up")
	assert_true(screen._ai_pending,
		"control: the Pause window's closing refresh armed a dwell")
	screen._ai_step()   # ...and that dwell's timer fires under the question
	assert_eq(counting.acted, 0, "the computer does not act under the question")
	screen._refresh()
	assert_false(screen._ai_pending, "and no new dwell is armed under it")
	screen._cancel_concede()
	await get_tree().process_frame
	assert_true(screen._ai_pending, "Cancel: the duel goes on, a dwell is armed")
	screen._ai_step()
	assert_eq(counting.acted, 1, "and the computer acts")


func test_escape_on_the_concede_question_lets_the_duel_go_on() -> void:
	await _vs_ai()
	var counting := _computer_to_act()
	screen._ask_to_concede()
	screen._refresh()
	assert_false(screen._ai_pending, "nothing armed under the question")
	screen._on_escape()
	assert_null(screen._concede_dialog, "control: Esc closed it")
	await get_tree().process_frame
	assert_true(screen._ai_pending, "the redraw at the end of the frame arms a dwell")
	screen._ai_step()
	assert_eq(counting.acted, 1)


func test_a_held_duels_leave_question_holds_the_computer() -> void:
	await _vs_ai()
	screen.leave_question = "Quit this match?"
	var counting := _computer_to_act()
	screen._open_pause()
	screen._on_pause_chosen(DuelPause.Action.EXIT_DUEL)
	assert_true(screen.leave_question_open(), "control: the held duel asks")
	screen._ai_step()
	assert_eq(counting.acted, 0, "the computer does not act under the question")
	screen._refresh()
	assert_false(screen._ai_pending)
	screen._cancel_leave()
	await get_tree().process_frame
	assert_true(screen._ai_pending, "Cancel: a dwell is armed again")
	screen._ai_step()
	assert_eq(counting.acted, 1)


## The standing orders and the automatic pass hold too: a Done order
## given before the question does not walk the duel on under it.
func test_the_automatic_pass_holds_under_the_question() -> void:
	await _vs_ai()
	screen.stops.clear_all()
	var g: MtgGame = screen.game
	g.players[0].hand.clear()
	g._probing = true
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP))
	g.priority_player = 0
	g._passes = 0
	g._probing = false
	assert_true(screen._auto_pass_applies(), "control: the unstopped upkeep would pass")
	screen._ask_to_concede()
	screen._drive_advance()
	assert_eq([g.current_step(), g.priority_player], [Mtg.Step.UPKEEP, 0],
		"nothing moved under the question")
	screen._cancel_concede()
	await get_tree().process_frame
	assert_false(g.current_step() == Mtg.Step.UPKEEP and g.priority_player == 0,
		"Cancel: the upkeep passes itself again")


# ===================================== h4-3: an automatic skip does not rest --

func _skip_fixture() -> MtgGame:
	await _vs_ai()
	screen.config.pace = 0.0
	screen.stops.clear_all()
	var g: MtgGame = screen.game
	g.players[0].hand.clear()
	g.players[1].hand.clear()
	for card_name in ["Wall of Swords", "Mountain"]:
		var inst := CardInstance.new(CardRegistry.get_card(card_name), _next_id, 0)
		_next_id += 1
		g._probing = true
		g._instances[inst.id] = inst
		g._put_on_battlefield(inst, 0)
		inst.summoning_sick = false
		g.recalculate()
		g._probing = false
	g._probing = true
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.COMBAT_BEGIN))
	g.awaiting_attackers = false
	g.awaiting_blockers = false
	g.priority_player = 0
	g._passes = 0
	g._probing = false
	screen.mode = DuelScreen.Mode.NORMAL
	return g


func test_an_automatic_skip_does_not_rest_in_main_two() -> void:
	var g := await _skip_fixture()
	assert_true(screen._auto_skip_applies(), "control: the combat goes by itself")
	screen._refresh()
	assert_eq(g.current_step(), Mtg.Step.MAIN2, "control: one refresh, Main 2")
	assert_eq(screen._rested_at, [], "nobody named Main 2: no rest mark")
	assert_true(screen._auto_pass_applies(), "the unstopped Main 2 passes itself")
	await get_tree().process_frame
	assert_false(g.current_step() == Mtg.Step.MAIN2 and g.priority_player == 0,
		"...at the end of the frame, with no click (step %d, priority %d)"
			% [g.current_step(), g.priority_player])


func test_the_skip_button_still_rests_in_main_two() -> void:
	var g := await _skip_fixture()
	screen.stops.set_marked(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 4, true)
	screen._refresh()
	assert_eq(g.current_step(), Mtg.Step.COMBAT_BEGIN, "control: the Stop holds the offer")
	screen._order_skip_combat()
	assert_eq(g.current_step(), Mtg.Step.MAIN2)
	assert_eq(screen._rested_at, screen._phase_key(),
		"the player's own Skip named Main 2: it rests there")
	assert_false(screen._auto_pass_applies())


# ======================================= h4-8: Pause holds the opening --

func test_pause_holds_the_splash_countdown() -> void:
	await _vs_ai()
	screen._run_intro()
	var intro: DuelIntro = screen._intro_overlay
	assert_true(intro.is_processing(), "control: the five seconds are running")
	screen._open_pause()
	assert_false(intro.is_processing(), "the Pause window stops them")
	intro._left = 0.01
	for _i in 3:
		await get_tree().process_frame
	assert_true(is_instance_valid(intro) and screen._intro_overlay == intro,
		"the splash is still up when its seconds would be gone")
	screen._close_pause()
	assert_true(intro.is_processing(), "closing the window lets them run again")
	for _i in 3:
		await get_tree().process_frame
	assert_null(screen._intro_overlay, "and at zero the splash goes on")


func test_a_countdown_the_question_stopped_stays_stopped() -> void:
	await _vs_ai()
	screen._run_intro()
	var intro: DuelIntro = screen._intro_overlay
	intro.set_process(false)   # the player touched it: the held duel's question
	screen._open_pause()
	screen._close_pause()
	assert_false(intro.is_processing(), "the pause does not restart what it did not stop")
	intro.go_pressed.emit()
	await get_tree().process_frame


func test_pause_holds_the_coin_toss() -> void:
	await _vs_ai()
	var toss := Control.new()
	screen.add_child(toss)
	screen._toss_overlay = toss
	screen._open_pause()
	assert_eq(toss.process_mode, Node.PROCESS_MODE_DISABLED,
		"the toss's spin and fade stand still under the window")
	screen._close_pause()
	assert_eq(toss.process_mode, Node.PROCESS_MODE_INHERIT, "and go on after it")
	screen._toss_overlay = null
	toss.queue_free()


func test_the_next_stage_of_the_opening_waits_for_the_pause() -> void:
	await _vs_ai()
	screen._open_pause()
	var done := [false]
	var waiter := func() -> void:
		await screen._await_unpaused()
		done[0] = true
	waiter.call()
	for _i in 3:
		await get_tree().process_frame
	assert_false(done[0], "nothing starts while the window is up")
	screen._close_pause()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(done[0], "and it starts once it is closed")
