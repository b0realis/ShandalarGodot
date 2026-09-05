extends GameTest
## §1.3 of docs/duel-todo.md — EVERY MID-RESOLUTION CHOICE IS A FIRST-CLASS
## QUESTION, on the record, and answerable in advance.
##
## The engine is synchronous, so a UI cannot open a dialog in the middle of
## a resolution. What it CAN do is answer beforehand and park the answer,
## and what the engine now guarantees is that nothing is decided off the
## record: every question becomes a PlayerChoice, is announced on
## `choice_requested`, lands in `choice_log`, and — when a seat that wanted
## to answer it did not — in `unanswered_choices` and the game log too.
##
## `choice_history` is what turns "the UI cannot see it coming" into "the
## UI cannot see it coming ONCE": almost every question in this pool is an
## upkeep trigger asking the same thing every turn.


func _junun(pid := 0) -> CardInstance:
	# "At the beginning of your upkeep, sacrifice Junún Efreet unless you
	# pay {B}{B}" — the shape 41 of the ~50 questions share.
	var efreet := put_battlefield(pid, "Junún Efreet")
	put_battlefield(pid, "Swamp")
	put_battlefield(pid, "Swamp")
	return efreet


## Walk to the UPKEEP of [param turn], where that turn's upkeep trigger is
## already on the chain and the resolution has not started.
func _to_upkeep_of_turn(turn: int) -> void:
	var guard := 0
	while not (g.turn_number == turn and g.current_step() == Mtg.Step.UPKEEP) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "did not reach turn %d's upkeep" % turn)


func test_a_mid_resolution_question_is_recorded_with_its_prompt() -> void:
	_junun(0)
	advance_to_next_turn()
	advance_to_next_turn()
	var asked := false
	for choice in g.choice_log:
		if choice.prompt.contains("Junún Efreet"):
			asked = true
			assert_eq(choice.kind, PlayerChoice.Kind.YES_NO)
			assert_eq(choice.pid, 0)
			assert_eq(choice.source, "Junún Efreet", "filed under the card that asked")
	assert_true(asked, "the upkeep question is on the record")


func test_the_signal_carries_every_question() -> void:
	var seen: Array[PlayerChoice] = []
	g.choice_requested.connect(func(c: PlayerChoice) -> void: seen.append(c))
	_junun(0)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(seen.size(), g.choice_log.size())
	assert_gt(seen.size(), 0)


func test_a_heuristic_answer_for_a_human_seat_is_ledgered_and_logged() -> void:
	g.agents[0] = HumanAgent.new()
	_junun(0)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_gt(g.unanswered_choices.size(), 0,
		"the referee answered for the player, and said so")
	var spoken := false
	for line in g.log_lines:
		if line.begins_with("(decided for P0)"):
			spoken = true
	assert_true(spoken, "and it is in the game log, not just in memory")


func test_a_parked_answer_is_the_players_own_and_is_not_ledgered() -> void:
	var human := HumanAgent.new()
	g.agents[0] = human
	var efreet := _junun(0)
	# Turn 3 is P0's next: the trigger is on the chain, so park "no".
	_to_upkeep_of_turn(3)
	assert_eq(g.active_player, 0)
	assert_eq(g.stack.size(), 1, "the upkeep trigger is waiting on the chain")
	var before := g.unanswered_choices.size()
	human.park(PlayerChoice.Kind.YES_NO, false)
	resolve_stack()
	assert_eq(efreet.zone, Mtg.Zone.GRAVEYARD,
		"the player declined to pay and the Efreet went")
	assert_eq(g.unanswered_choices.size(), before,
		"a choice the player made is not on the unanswered ledger")


func test_a_stale_discard_pick_is_not_the_players_answer() -> void:
	# The overlay parks the names it was clicked on; if the hand has
	# changed underneath them, the referee picks instead — and until
	# 2026-09-02 that pick was still filed as "answered by the player",
	# because `_take` marked the question before the pick was checked.
	var human := HumanAgent.new()
	g.agents[0] = human
	give_hand(0, "Grizzly Bears")
	give_hand(0, "Forest")
	human.park(PlayerChoice.Kind.DISCARD, ["Lightning Bolt"])
	var picked := human.choose_discard(g, 0, 1)
	assert_eq(picked.size(), 1, "the referee discarded one card")
	assert_false(g.choice_log.back().answered_by_player,
		"a heuristic answer is not the player's, whatever was parked")
	human.park(PlayerChoice.Kind.DISCARD, ["Forest"])
	picked = human.choose_discard(g, 0, 1)
	assert_eq(picked[0].data.card_name, "Forest")
	assert_true(g.choice_log.back().answered_by_player,
		"a usable pick is the player's own")


func test_a_parked_answer_never_leaks_into_the_next_resolution() -> void:
	var human := HumanAgent.new()
	g.agents[0] = human
	var efreet := _junun(0)
	_to_upkeep_of_turn(3)
	# Park two answers where only one is asked for.
	human.park(PlayerChoice.Kind.YES_NO, true)
	human.park(PlayerChoice.Kind.YES_NO, false)
	resolve_stack()
	assert_eq(efreet.zone, Mtg.Zone.BATTLEFIELD, "the first answer paid")
	assert_false(human.has_parked(),
		"the leftover is dropped when the resolution ends")


func test_a_card_remembers_what_it_asked_so_the_second_time_is_foreseeable() -> void:
	_junun(0)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(g.choice_history.has("Junún Efreet"),
		"the UI can look the question up before letting it resolve again")
	var recorded: Array = g.choice_history["Junún Efreet"]
	assert_eq(recorded.size(), 1)
	assert_eq((recorded[0] as PlayerChoice).kind, PlayerChoice.Kind.YES_NO)
	assert_string_contains((recorded[0] as PlayerChoice).prompt, "Junún Efreet")


func test_the_ai_and_the_default_agent_still_answer_their_own() -> void:
	_junun(1)
	advance_to_next_turn()
	assert_eq(g.unanswered_choices.size(), 0,
		"a seat that never wanted to be asked is not owed anything")
