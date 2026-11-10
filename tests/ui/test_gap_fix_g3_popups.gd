extends GameTest
## THE CAST'S OWN WINDOWS AND THE DUEL AROUND THEM (gap review 2026-11-10).
##
##  * r3-3 — the duel's verdict dropped the cast in hand but left its X
##    question and its tutor picker standing over the End of Duel window.
##    Whatever drops the pending cast now closes both.
##  * The owner's default for its question: the computer does not act while
##    a human seat's X question, tutor picker or mode menu is open — as
##    under the Pause window, the mini help and the card reader — and goes
##    on the moment it closes.
##  * r3-4 — at a table of two humans a seat's OWN end step read "their
##    turn is ending", the other seat's opponent's-end-step window: the
##    window asked the drawing perspective (seat 0) and not the seat the
##    screen serves.

var screen: DuelScreen


func after_each() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _open(config: DuelConfig) -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	g = screen.game


func _vs_ai(seed := 93820) -> DuelConfig:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 1000.0
	config.rng_seed = seed
	return config


func _stand(pid: int, step := Mtg.Step.MAIN1) -> void:
	g.active_player = pid
	g._enter_step(Mtg.STEP_ORDER.find(step))
	g.priority_player = pid
	screen.mode = DuelScreen.Mode.NORMAL
	screen._refresh()


## Freed, or on its way: untyped, since a freed object fails a typed slot.
func _gone(node: Variant) -> bool:
	return not is_instance_valid(node) or (node as Node).is_queued_for_deletion()


# ======================================== r3-3: the verdict closes them ---

func test_the_verdict_closes_the_x_question() -> void:
	await _open(_vs_ai())
	_stand(0)
	for i in 3:
		put_battlefield(0, "Mountain")
	var fireball := give_hand(0, "Fireball")
	screen._refresh()
	screen._on_card_clicked(fireball)
	assert_not_null(screen._x_dialog, "control: the X question is up")
	var dialog: Node = screen._x_dialog
	g.lose_game(0, "probe")
	await get_tree().process_frame
	assert_null(screen._x_dialog, "the screen forgets it")
	assert_true(_gone(dialog), "the verdict closes the X question")
	assert_null(screen._pending_card, "control: and the cast is dropped")


func test_the_verdict_closes_the_tutor_picker() -> void:
	await _open(_vs_ai(93821))
	_stand(0)
	put_battlefield(0, "Swamp")
	var tutor := give_hand(0, "Demonic Tutor")
	screen._refresh()
	screen._on_card_clicked(tutor)
	assert_not_null(screen._search_dialog, "control: the tutor picker is up")
	var dialog: Node = screen._search_dialog
	g.lose_game(0, "probe")
	await get_tree().process_frame
	assert_null(screen._search_dialog, "the screen forgets it")
	assert_true(_gone(dialog), "the verdict closes the tutor picker")


# ============================ the computer waits under the cast's windows ---

## What the computer doing anything would change.
func _beat() -> Array:
	return [g.priority_player, g.current_step(), g.turn_number, g.stack.size(),
		g.log_lines.size(), g.players[1].battlefield.size()]


## The computer's own main phase, with nothing to do but pass; the human
## reaches for an instant while the computer holds priority.
func _computers_beat(lands: String, count: int) -> void:
	await _open(_vs_ai(93822))
	for i in count:
		put_battlefield(0, lands)
	g.players[1].hand.clear()
	_stand(1)
	assert_eq(g.priority_player, 1, "control: the computer holds priority")


func _assert_the_computer_waits(what: String) -> void:
	var before := _beat()
	screen._ai_pending = false
	screen._maybe_schedule_ai()
	assert_false(screen._ai_pending, "no dwell is armed under the %s" % what)
	screen._ai_step()   # one armed before the window opened
	assert_eq(_beat(), before, "the computer does not act under the %s" % what)


func _assert_the_computer_goes_on() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	screen._refresh()
	assert_true(screen._ai_pending, "the window closed: the computer's dwell is armed again")
	var before := _beat()
	screen._ai_step()
	assert_ne(_beat(), before, "and the computer acts")


func test_the_computer_waits_while_the_x_question_is_open() -> void:
	await _computers_beat("Plains", 2)
	var angel := give_hand(0, "Guardian Angel")
	screen._on_card_clicked(angel)
	assert_not_null(screen._x_dialog, "control: the X question is up on the computer's beat")
	_assert_the_computer_waits("X question")
	screen._on_x_canceled()
	await _assert_the_computer_goes_on()


func test_the_computer_waits_while_the_mode_menu_is_open() -> void:
	await _computers_beat("Plains", 3)
	var potion := give_hand(0, "Alabaster Potion")
	screen._on_card_clicked(potion)
	assert_not_null(screen._mode_overlay, "control: the mode menu is up on the computer's beat")
	_assert_the_computer_waits("mode menu")
	screen._on_mode_canceled()
	await _assert_the_computer_goes_on()


func test_the_computer_waits_while_the_tutor_picker_is_open() -> void:
	await _open(_vs_ai(93823))
	put_battlefield(0, "Swamp")
	g.players[1].hand.clear()
	_stand(0)
	var tutor := give_hand(0, "Demonic Tutor")
	screen._on_card_clicked(tutor)
	assert_not_null(screen._search_dialog, "control: the tutor picker is up")
	# Setup: the computer is the one to act while the picker stands.
	g.priority_player = 1
	_assert_the_computer_waits("tutor picker")
	screen._on_search_canceled()
	await _assert_the_computer_goes_on()


# ============================== r3-4: a seat's own end step, two humans ---

func test_a_seats_own_end_step_is_no_window_at_a_two_human_table(pid = use_parameters([0, 1])) -> void:
	var config := DuelConfig.hotseat_default()
	config.rng_seed = 93824
	await _open(config)
	assert_false(screen.config.private_hotseat(), "control: an open table of two humans")
	_stand(int(pid), Mtg.Step.END)
	assert_eq(screen._viewing_seat(), int(pid), "control: the screen serves seat %d" % int(pid))
	assert_eq(screen._instant_window_reason(), "",
		"seat %d's own end step is no 'their turn is ending' window" % int(pid))
	g.priority_player = 1 - int(pid)
	assert_eq(screen._instant_window_reason(), "their turn is ending",
		"while the other seat holds priority in it, it is that seat's window")


func test_a_seats_own_end_step_is_no_window_at_a_private_hotseat(pid = use_parameters([0, 1])) -> void:
	var config := DuelConfig.hotseat_default()
	config.hotseat_privacy = true
	config.rng_seed = 93825
	await _open(config)
	_stand(int(pid), Mtg.Step.END)
	assert_eq(screen._instant_window_reason(), "",
		"seat %d's own end step is no 'their turn is ending' window" % int(pid))


func test_against_the_computer_the_window_is_as_before() -> void:
	await _open(_vs_ai(93826))
	_stand(1, Mtg.Step.END)
	g.priority_player = 0
	assert_eq(screen._instant_window_reason(), "their turn is ending", "the computer's end step")
	_stand(0, Mtg.Step.END)
	assert_eq(screen._instant_window_reason(), "", "the human's own")
