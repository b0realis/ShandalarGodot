extends GameTest
## Pack 8 engine package E8 — turn structure: skipping a turn (`N_skip_turn`,
## Chronatog), skipping an untap step (`N_skip_untap_step`, Avizoa's one-shot
## and Sands of Time's static), an action "during your next untap step, as
## you untap your permanents" (`N_untap_action`, Undiscovered Paradise) and
## the beginning of a main phase as an event (`N_main_phase_event`,
## Ventifact Bottle).
##
## The rules pinned here:
## - "skip" is a replacement (CR 614.10): the skipped step or turn does not
##   happen at all; two such effects skip the next two (614.10a); anything
##   scheduled for "your next" one waits for the first that is not skipped;
## - a skipped untap step neither untaps nor phases (CR 702.26m), but the
##   TURN still began — summoning sickness ends (CR 302.6) and the land drop
##   resets;
## - only the turn's first main phase is precombat (CR 505.1a).
## Every card is synthetic.

var heard: Array = []


func before_each() -> void:
	super.before_each()
	heard = []


func _bear(pid: int, card_name := "Test Bear") -> CardInstance:
	return put_synthetic(pid, CardData.new(card_name, "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2))


static func _skip_all_untaps(game: MtgGame, _source: CardInstance) -> void:
	for p in game.players:
		p.skips_untap_step = true


## Sands of Time's first line as a synthetic static.
func _sands(pid: int) -> CardInstance:
	return put_synthetic(pid, CardData.new("Test Sands", "{4}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(_skip_all_untaps, "Each player skips their untap step.")))


# ---------------------------------------------------- skipping an untap step --

func test_a_skipped_untap_step_untaps_nothing_but_the_turn_still_begins() -> void:
	var tapped := _bear(0, "Tapped Bear")
	g.tap_permanent(tapped)
	var fresh := _bear(0, "Fresh Bear")
	fresh.summoning_sick = true
	var land := give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.play_land(0, land))
	g.tap_permanent(land)
	g.skip_next_untap_step(0)   # Avizoa: "You skip your next untap step."
	advance_to_next_turn()
	advance_to_next_turn()      # turn 3, P0
	assert_eq(g.active_player, 0)
	assert_true(tapped.tapped, "nothing untapped")
	assert_true(land.tapped)
	assert_false(fresh.summoning_sick,
		"CR 302.6 asks only for control since the turn began")
	assert_eq(g.players[0].lands_played_this_turn, 0, "a new turn's land drop")
	assert_eq(g.players[0].skip_untap_steps, 0, "consumed")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [fresh.id]))
	advance_to_next_turn()
	advance_to_next_turn()      # turn 5, P0: a normal untap step again
	assert_false(tapped.tapped)
	assert_false(land.tapped)


func test_two_skips_skip_the_next_two_untap_steps() -> void:
	var tapped := _bear(0)
	g.tap_permanent(tapped)
	g.skip_next_untap_step(0)
	g.skip_next_untap_step(0)   # CR 614.10a
	advance_to_next_turn()
	advance_to_next_turn()      # turn 3
	assert_true(tapped.tapped)
	advance_to_next_turn()
	advance_to_next_turn()      # turn 5
	assert_true(tapped.tapped)
	advance_to_next_turn()
	advance_to_next_turn()      # turn 7
	assert_false(tapped.tapped)


func test_only_the_named_players_untap_step_is_skipped() -> void:
	var theirs := _bear(1)
	g.tap_permanent(theirs)
	g.skip_next_untap_step(0)
	advance_to_next_turn()      # turn 2, P1 untaps as usual
	assert_false(theirs.tapped)


func test_a_skipped_untap_step_does_not_phase() -> void:
	# CR 702.26m: "If an effect causes a player to skip their untap step,
	# the phasing event simply doesn't occur that turn."
	var drake := put_synthetic(0, CardData.new("Test Drake", "{2}{U}",
		Mtg.CardType.CREATURE).pt(1, 3).with_keywords([Mtg.Keyword.PHASING]))
	var gone := _bear(0)
	assert_true(g.phase_out(gone))
	g.skip_next_untap_step(0)
	advance_to_next_turn()
	advance_to_next_turn()      # turn 3: skipped
	assert_false(drake.phased_out, "no phasing out")
	assert_true(gone.phased_out, "no phasing in")
	advance_to_next_turn()
	advance_to_next_turn()      # turn 5: the step happens
	assert_true(drake.phased_out)
	assert_false(gone.phased_out)


func test_a_static_skip_skips_every_untap_step_while_it_lasts() -> void:
	var sands := _sands(0)
	var mine := _bear(0)
	var theirs := _bear(1)
	g.tap_permanent(mine)
	g.tap_permanent(theirs)
	assert_true(g.players[0].skips_untap_step and g.players[1].skips_untap_step)
	advance_to_next_turn()      # P1
	assert_true(theirs.tapped, "Sands of Time: each player skips")
	advance_to_next_turn()      # P0
	assert_true(mine.tapped)
	g.destroy(sands)
	assert_false(g.players[0].skips_untap_step, "rebuilt by the pipeline")
	advance_to_next_turn()
	assert_false(theirs.tapped)


func test_a_pending_one_shot_is_spent_on_a_step_the_static_skips() -> void:
	# Both replacements want the same step; the affected player applies the
	# one-shot (CR 616.1) — keeping it would only skip a later step too.
	var sands := _sands(1)
	var mine := _bear(0)
	g.tap_permanent(mine)
	g.skip_next_untap_step(0)
	advance_to_next_turn()
	advance_to_next_turn()      # turn 3: skipped by both
	assert_true(mine.tapped)
	assert_eq(g.players[0].skip_untap_steps, 0)
	g.destroy(sands)
	advance_to_next_turn()
	advance_to_next_turn()      # turn 5: nothing left to skip it
	assert_false(mine.tapped)


func test_next_untap_step_effects_wait_for_one_that_happens() -> void:
	# CR 614.10a: "Anything scheduled for the 'next' occurrence of
	# something waits for the first occurrence that isn't skipped."
	var held := _bear(0)
	g.tap_permanent(held)
	g.skip_untap_during_next_step(held, 0)   # "doesn't untap during your next untap step"
	g.skip_next_untap_step(0)
	advance_to_next_turn()
	advance_to_next_turn()      # turn 3: skipped — the lock is not spent
	assert_true(held.skip_untap_for.has(0))
	advance_to_next_turn()
	advance_to_next_turn()      # turn 5: the lock holds it down, and is spent
	assert_true(held.tapped)
	assert_false(held.skip_untap_for.has(0))
	advance_to_next_turn()
	advance_to_next_turn()      # turn 7
	assert_false(held.tapped)


func test_an_until_your_next_untap_step_effect_outlives_a_skipped_step() -> void:
	var bear := _bear(0)
	g.continuous.add_floating_static(bear, StaticAbility.new(
		func(_game: MtgGame, source: CardInstance) -> void:
			source.cur_power += 5,
		"+5/+0 until your next untap step."),
		ContinuousEffects.Duration.UNTIL_UNTAP_OF, 0, false, bear.id)
	g.recalculate()
	assert_eq(bear.cur_power, 7)
	g.skip_next_untap_step(0)
	advance_to_next_turn()
	advance_to_next_turn()      # skipped: the effect waits
	assert_eq(bear.cur_power, 7)
	advance_to_next_turn()
	advance_to_next_turn()      # the step happens: it ends
	assert_eq(bear.cur_power, 2)


func test_the_untap_skip_round_trips_under_the_journal() -> void:
	var mark := g.make_mark()
	g.skip_next_untap_step(0)
	g.skip_next_turn(1)
	assert_eq(g.players[0].skip_untap_steps, 1)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(g.players[0].skip_untap_steps, 0)
	assert_eq(g.players[1].turns_to_skip, 0)


func test_a_skipped_untap_step_under_the_fifth_edition_rules() -> void:
	g.rules.set_edition("fifth")
	var tapped := _bear(0)
	g.tap_permanent(tapped)
	g.skip_next_untap_step(0)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	assert_true(tapped.tapped)
	assert_false(g.game_over)


# ------------------------------------------------------------ skipping a turn --

func test_skipping_the_next_turn_hands_the_opponent_two_in_a_row() -> void:
	var tapped := _bear(0)
	g.tap_permanent(tapped)
	var hand := g.players[0].hand.size()
	g.skip_next_turn(0)          # Chronatog: "You skip your next turn."
	advance_to_next_turn()       # turn 2, P1
	assert_eq(g.active_player, 1)
	advance_to_next_turn()       # turn 3 was P0's: skipped whole
	assert_eq(g.active_player, 1, "P1 again")
	assert_eq(g.turn_number, 4)
	assert_true(tapped.tapped, "no untap step in a skipped turn")
	assert_eq(g.players[0].hand.size(), hand, "no draw step either")
	assert_eq(g.players[0].turns_to_skip, 0)
	advance_to_next_turn()       # turn 5: P0 plays again
	assert_eq(g.active_player, 0)
	assert_false(tapped.tapped)


func test_two_turn_skips_skip_two_turns() -> void:
	g.skip_next_turn(0)
	g.skip_next_turn(0)
	advance_to_next_turn()       # 2: P1
	advance_to_next_turn()       # 3 skipped, 4: P1
	advance_to_next_turn()       # 5 skipped, 6: P1
	assert_eq(g.active_player, 1)
	assert_eq(g.turn_number, 6)
	advance_to_next_turn()
	assert_eq(g.active_player, 0)


func test_a_skip_made_on_the_opponents_turn_skips_your_next() -> void:
	advance_to_next_turn()       # turn 2, P1
	g.skip_next_turn(0)
	advance_to_next_turn()       # turn 3 (P0) skipped → turn 4, P1
	assert_eq(g.active_player, 1)
	assert_eq(g.turn_number, 4)


# ------------------------------------------------ "as you untap" (Paradise) --

func test_an_untap_step_action_runs_as_its_player_untaps() -> void:
	var land := put_battlefield(0, "Forest")
	g.tap_permanent(land)
	var seen: Array = []
	g.schedule_untap_step_action(0, func(game: MtgGame) -> void:
		seen.append([game.active_player, game.current_step(), land.tapped]))
	advance_to_next_turn()       # P1's untap step: not P0's
	assert_true(seen.is_empty())
	advance_to_next_turn()       # P0's
	assert_eq(seen, [[0, Mtg.Step.UNTAP, false]],
		"during P0's untap step, as P0's permanents untap")


func test_undiscovered_paradise_shape_returns_the_land() -> void:
	var land := put_battlefield(0, "Forest")
	g.schedule_untap_step_action(0, func(game: MtgGame) -> void:
		game.return_to_hand(land), land)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(land.zone, Mtg.Zone.HAND)


func test_an_untap_step_action_waits_through_a_skipped_untap_step() -> void:
	var runs: Array = []
	g.schedule_untap_step_action(0, func(_game: MtgGame) -> void: runs.append(1))
	g.skip_next_untap_step(0)
	advance_to_next_turn()
	advance_to_next_turn()       # turn 3: skipped
	assert_true(runs.is_empty())
	advance_to_next_turn()
	advance_to_next_turn()       # turn 5
	assert_eq(runs, [1])


func test_an_untap_step_action_forgets_a_permanent_that_left() -> void:
	# CR 400.7: the land that comes back is a new object.
	var land := put_battlefield(0, "Forest")
	var runs: Array = []
	g.schedule_untap_step_action(0, func(_game: MtgGame) -> void: runs.append(1), land)
	g.return_to_hand(land)
	g._put_on_battlefield(land, 0)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(runs.is_empty())


func test_an_untap_step_action_round_trips_under_the_journal() -> void:
	var mark := g.make_mark()
	g.schedule_untap_step_action(0, func(_game: MtgGame) -> void: pass)
	g.unmake_to(mark)
	g.end_search()
	var runs: Array = []
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(runs.is_empty())
	assert_true(g._untap_actions.is_empty())


# ------------------------------------------------ the beginning of a main phase --

func _main_watcher(pid: int) -> CardInstance:
	var c := CardData.new("Test Bottle", "{3}", Mtg.CardType.ARTIFACT)
	c.triggered(TriggeredAbility.new(Mtg.EventType.MAIN_PHASE_START,
		func(_game: MtgGame, _s: CardInstance, event: GameEvent) -> void:
			heard.append(bool(event.data.get("precombat", false))),
		"At the beginning of each of your main phases, note it.",
		func(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
			return int(event.data.get("player", -1)) == source.controller_id))
	return put_synthetic(pid, c)


func test_each_main_phase_begins_with_an_event() -> void:
	_main_watcher(0)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.stack.size(), 1, "the trigger waits for the main phase's priority")
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN2)
	resolve_stack()
	assert_eq(heard, [true, false], "only the first main phase is precombat (505.1a)")
	advance_to_next_turn()       # P1's turn: not the watcher's
	assert_eq(heard.size(), 2)


func test_a_main_phase_after_an_extra_combat_is_postcombat() -> void:
	_main_watcher(0)
	advance_to_step(Mtg.Step.MAIN1)
	resolve_stack()
	g.add_combat_after_current_main()
	advance_to_step(Mtg.Step.MAIN2)
	resolve_stack()
	advance_to_step(Mtg.Step.END)
	assert_eq(heard, [true, false, false])


# ------------------------- the untap step's triggers join the upkeep's (CR 503.1a) --
#
# "Any abilities that triggered during the untap step and any abilities that
# triggered at the beginning of the upkeep are put onto the stack before the
# active player gets priority; the order in which they triggered doesn't
# matter." One batch: APNAP, each controller ordering their own (CR 603.3b).

const ORDER_PROMPT := "Which of your triggered abilities resolves first?"


## Answers OPTION questions from a queue — an index or a label fragment —
## and records every prompt it was asked.
class OrderSeat extends DecisionAgent:
	var options: Array = []
	var asked: Array[String] = []

	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			labels: Array[String], hint: int) -> int:
		asked.append(prompt)
		if options.is_empty():
			return hint
		var want: Variant = options.pop_front()
		if want is String:
			for i in labels.size():
				if labels[i].to_lower().contains(String(want).to_lower()):
					return i
			return hint
		return int(want)


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


## A creature whose phase-in and "at the beginning of your upkeep" triggers
## note, as they RESOLVE, [turn, "<tag> in" / "<tag> upkeep"].
func _two_triggers(pid: int, tag: String) -> CardInstance:
	var c := CardData.new("Test %s" % tag, "{1}{U}", Mtg.CardType.CREATURE).pt(1, 1)
	c.triggered(TriggeredAbility.new(Mtg.EventType.PHASED_IN,
		func(game: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
			heard.append([game.turn_number, "%s in" % tag]),
		"Whenever this creature phases in, note it.", _is_self))
	c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
		func(game: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
			heard.append([game.turn_number, "%s upkeep" % tag]),
		"At the beginning of your upkeep, note it.",
		func(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
			return int(event.data.get("player", -1)) == source.controller_id))
	return put_synthetic(pid, c)


## What resolved on [param turn], in order.
func _heard_on(turn: int) -> Array:
	var out: Array = []
	for row in heard:
		if int(row[0]) == turn:
			out.append(row[1])
	return out


func test_an_untap_step_trigger_may_resolve_before_the_upkeep_trigger() -> void:
	# Warping Wurm's shape: phased in during the untap step, phases out at the
	# upkeep unless paid — the phase-in trigger must be able to go first.
	var wurm := _two_triggers(0, "P0")
	assert_true(g.phase_out(wurm))
	advance_to_next_turn()
	advance_to_next_turn()      # turn 3: in at the untap step, then the upkeep
	assert_eq(_heard_on(3), ["P0 in", "P0 upkeep"],
		"one batch; by default the trigger that fired first resolves first")


func test_the_controller_orders_their_own_batch() -> void:
	var seat := OrderSeat.new()
	g.set_agent(0, seat)
	var wurm := _two_triggers(0, "P0")
	assert_true(g.phase_out(wurm))
	seat.options = ["upkeep"]   # "which resolves first?" — the upkeep one
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(_heard_on(3), ["P0 upkeep", "P0 in"], "the controller's order")
	assert_eq(seat.asked.count(ORDER_PROMPT), 1, "two triggers: one question")


func test_a_single_trigger_asks_nothing() -> void:
	var seat := OrderSeat.new()
	g.set_agent(0, seat)
	var c := CardData.new("Test Lone", "{1}", Mtg.CardType.ARTIFACT)
	c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
		func(game: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
			heard.append([game.turn_number, "lone"]),
		"At the beginning of your upkeep, note it.",
		func(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
			return int(event.data.get("player", -1)) == source.controller_id))
	put_synthetic(0, c)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(_heard_on(3), ["lone"])
	assert_eq(seat.asked.count(ORDER_PROMPT), 0)


func test_the_batch_is_apnap_across_both_players() -> void:
	# The non-active player's triggers go on the stack AFTER all of the active
	# player's and resolve first — the untap step's included (CR 603.3b).
	var mine := _two_triggers(0, "P0")
	var c := CardData.new("Test Watcher", "{1}", Mtg.CardType.ARTIFACT)
	c.triggered(TriggeredAbility.new(Mtg.EventType.PHASED_IN,
		func(game: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
			heard.append([game.turn_number, "P1 sees"]),
		"Whenever a permanent an opponent controls phases in, note it.",
		func(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
			return int(event.data.get("controller", -1)) != source.controller_id))
	c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
		func(game: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
			heard.append([game.turn_number, "P1 upkeep"]),
		"At the beginning of each upkeep, note it."))
	put_synthetic(1, c)
	assert_true(g.phase_out(mine))
	advance_to_next_turn()
	advance_to_next_turn()      # turn 3, P0 active
	assert_eq(_heard_on(3), ["P1 sees", "P1 upkeep", "P0 in", "P0 upkeep"])


func test_a_human_seat_is_held_on_the_ordering_question() -> void:
	var human := HumanAgent.new()
	g.agents[0] = human
	g.interactive_choices = true
	var wurm := _two_triggers(0, "P0")
	assert_true(g.phase_out(wurm))
	var guard := 0
	while g.awaiting_choice == null and not g.game_over and g.turn_number <= 3 \
			and guard < 400:
		_advance_once()
		guard += 1
	var q := g.awaiting_choice
	assert_not_null(q, "held as the upkeep's batch goes on the stack")
	assert_eq(q.prompt, ORDER_PROMPT)
	assert_eq(q.pid, 0)
	assert_eq(q.options.size(), 2)
	assert_eq(g.turn_number, 3)
	assert_eq(g.current_step(), Mtg.Step.UPKEEP)
	assert_eq(g.stack.size(), 0, "nothing goes on until the order is known")
	var upkeep_first := -1
	for i in q.options.size():
		if q.options[i].contains("upkeep"):
			upkeep_first = i
	assert_ok(g.answer_choice(upkeep_first))
	assert_null(g.awaiting_choice)
	assert_eq(g.stack.size(), 2)
	assert_eq(g.priority_player, 0, "and the active player gets priority")
	assert_eq(g.stack.back().trigger.event_type, Mtg.EventType.UPKEEP_START,
		"the one chosen to resolve first is on top")
	assert_eq(g.stack[0].trigger.event_type, Mtg.EventType.PHASED_IN)
	# (The pre-flight probe re-runs each resolution under a human seat, and
	# the test's own note-taking is not game state — so stop asking first.)
	g.interactive_choices = false
	resolve_stack()
	assert_eq(_heard_on(3), ["P0 upkeep", "P0 in"])


func test_the_upkeep_batch_round_trips_under_the_journal() -> void:
	var wurm := _two_triggers(0, "P0")
	assert_true(g.phase_out(wurm))
	advance_to_next_turn()
	advance_to_step(Mtg.Step.END)
	var stack_before := g.stack.size()
	var mark := g.make_mark()
	advance_to_step(Mtg.Step.UPKEEP)   # turn 3: the batch is on the stack
	assert_eq(g.stack.size(), 2)
	assert_false(g._stack_frozen)
	g.unmake_to(mark)
	g.end_search()
	assert_true(wurm.phased_out)
	assert_false(g._stack_frozen)
	assert_true(g._waiting_triggers.is_empty())
	assert_eq(g.stack.size(), stack_before)


func test_a_batch_from_one_moment_keeps_its_order_unasked() -> void:
	# Two "at the beginning of your upkeep" triggers (Tetravus): no untap-step
	# trigger among them, so the engine-wide convention stands — the order
	# they triggered in, nobody asked.
	var seat := OrderSeat.new()
	g.set_agent(0, seat)
	var c := CardData.new("Test Twin", "{1}", Mtg.CardType.ARTIFACT)
	for tag in ["first", "second"]:
		c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
			func(game: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
				heard.append([game.turn_number, tag]),
			"At the beginning of your upkeep, note %s." % tag,
			func(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
				return int(event.data.get("player", -1)) == source.controller_id))
	put_synthetic(0, c)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(_heard_on(3), ["second", "first"], "as before: the later one on top")
	assert_eq(seat.asked.count(ORDER_PROMPT), 0)
