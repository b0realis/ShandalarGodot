extends GameTest
## THE UNTAP STEP'S QUESTIONS (CR 502.3), and the turn-based HOLD that puts
## them to a human seat. The pre-flight only wraps stack resolutions and the
## cost hold only wraps actions; an untap step is neither, so it re-uses the
## cost hold's record-and-replay: every decision is collected before a
## single permanent is touched, the step is held open on
## MtgGame.awaiting_choice, and MtgGame.answer_choice re-runs it from the
## top with the answer parked (MtgGame._untap_step).
##
## Two families of question live here:
## - untap CAPS (Smoke, Winter Orb, Damping Field): WHICH permanent untaps
##   is the controller's choice (`@SMOKE`: "Select creature to untap.");
## - "you may choose not to untap" permanents (Old Man of the Sea and its
##   kin): whether it untaps is the controller's choice, in the 1997 form
##   (`@ISLAND_FISH_JASCONIUS`: "Untap Island Fish." / "Don't untap.").


func _human_seat(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


## Pass priority until the next turn's untap step holds on a question.
func _advance_until_held() -> void:
	var guard := 0
	while g.awaiting_choice == null and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_not_null(g.awaiting_choice, "the untap step held on a question")


## Picks named cards, in order.
class ListSeat extends DecisionAgent:
	var picks: Array = []

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		if picks.is_empty():
			return null
		var wanted := String(picks.pop_front())
		for inst in candidates:
			if inst.data.card_name == wanted:
				return inst
		return null


## Answers every option question with a fixed index.
class OptionSeat extends DecisionAgent:
	var index := 0

	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			_options: Array[String], _hint: int) -> int:
		return index


# --------------------------------------------------------------- Smoke --

func test_smoke_lets_the_controller_choose_which_creature_untaps() -> void:
	put_battlefield(0, "Smoke")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	bears.tapped = true
	giant.tapped = true
	var seat := ListSeat.new()
	seat.picks = ["Hill Giant"]
	g.agents[0] = seat
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()   # the opponent's turn
	advance_to_next_turn()   # ours again: the untap step has run
	assert_false(giant.tapped, "the seat named the Giant")
	assert_true(bears.tapped, "so the Bears stayed tapped")


func test_smoke_default_seat_untaps_the_first_in_battlefield_order() -> void:
	put_battlefield(0, "Smoke")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	bears.tapped = true
	giant.tapped = true
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(bears.tapped)
	assert_true(giant.tapped)


func test_smoke_holds_a_human_seat_in_the_untap_step() -> void:
	put_battlefield(0, "Smoke")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var forest := put_battlefield(0, "Forest")
	bears.tapped = true
	giant.tapped = true
	forest.tapped = true
	var human := _human_seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()
	_advance_until_held()
	assert_eq(g.current_step(), Mtg.Step.UNTAP, "held IN the untap step")
	assert_eq(g.awaiting_choice.pid, 0)
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.CARD)
	assert_eq(g.awaiting_choice.source, "Smoke", "the question wears the lock's name")
	assert_eq(g.awaiting_choice.prompt, "Select creature to untap.")
	assert_false(g.awaiting_choice.is_cost, "a turn-based action, not a cost")
	assert_eq(g.awaiting_choice.candidates.size(), 2)
	assert_true(bears.tapped, "nothing untapped while held")
	assert_true(forest.tapped, "not even the uncapped land")
	assert_refused(g.pass_priority(0), "waiting for a choice")
	assert_ok(g.answer_choice("Hill Giant"))
	assert_null(g.awaiting_choice)
	assert_false(giant.tapped, "the named creature untapped")
	assert_true(bears.tapped)
	assert_false(forest.tapped, "and the rest of the step ran")
	assert_eq(g.current_step(), Mtg.Step.UPKEEP, "the turn moved on")
	assert_false(human.has_parked(), "the answer was spent")


func test_a_permanent_of_two_capped_kinds_counts_against_both() -> void:
	# An artifact creature under Smoke AND Damping Field: untapping it
	# uses up both caps, so neither the other creature nor the other
	# artifact untaps.
	put_battlefield(0, "Smoke")
	put_battlefield(0, "Damping Field")
	var golem := put_battlefield(0, "Obsianus Golem")   # artifact creature
	var bears := put_battlefield(0, "Grizzly Bears")
	var rod := put_battlefield(0, "Iron Star")           # artifact
	golem.tapped = true
	bears.tapped = true
	rod.tapped = true
	var seat := ListSeat.new()
	seat.picks = ["Obsianus Golem"]
	g.agents[0] = seat
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(golem.tapped)
	assert_true(bears.tapped, "Smoke's one creature was the Golem")
	assert_true(rod.tapped, "and so was Damping Field's one artifact")


func test_the_opponent_is_asked_in_their_own_untap_step() -> void:
	put_battlefield(0, "Smoke")
	var theirs_a := put_battlefield(1, "Grizzly Bears")
	var theirs_b := put_battlefield(1, "Hill Giant")
	theirs_a.tapped = true
	theirs_b.tapped = true
	var seat := ListSeat.new()
	seat.picks = ["Hill Giant"]
	g.agents[1] = seat
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_false(theirs_b.tapped)
	assert_true(theirs_a.tapped)


# --------------------------------------------------- Old Man of the Sea --

func test_old_man_keeps_his_catch_by_default() -> void:
	# "You may choose not to untap" — the heuristic stays tapped while the
	# leash is alive.
	var old_man := put_battlefield(0, "Old Man of the Sea")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, old_man, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.controller_id, 0)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(old_man.tapped, "still tapped")
	assert_eq(bear.controller_id, 0, "and the Bears are still ours")


func test_old_man_untaps_when_the_seat_says_so() -> void:
	var old_man := put_battlefield(0, "Old Man of the Sea")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, old_man, 0, [TargetRef.card(bear)]))
	resolve_stack()
	var seat := OptionSeat.new()
	seat.index = 0          # "Untap Old Man of the Sea."
	g.agents[0] = seat
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(old_man.tapped, "the seat chose to untap")
	assert_eq(bear.controller_id, 1, "so the leash broke and the Bears went home")


func test_old_man_untap_is_a_question_for_a_human_seat() -> void:
	var old_man := put_battlefield(0, "Old Man of the Sea")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, old_man, 0, [TargetRef.card(bear)]))
	resolve_stack()
	_human_seat(0)
	advance_to_next_turn()
	_advance_until_held()
	assert_eq(g.current_step(), Mtg.Step.UNTAP)
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.OPTION)
	assert_eq(g.awaiting_choice.source, "Old Man of the Sea")
	assert_eq(g.awaiting_choice.options, ["Untap Old Man of the Sea.", "Don't untap."])
	assert_eq(g.awaiting_choice.hint, 1, "the hint is to keep the catch")
	assert_ok(g.answer_choice(1))
	assert_null(g.awaiting_choice)
	assert_true(old_man.tapped)
	assert_eq(bear.controller_id, 0)
	assert_eq(g.current_step(), Mtg.Step.UPKEEP)


func test_an_untapped_old_man_asks_nothing() -> void:
	put_battlefield(0, "Old Man of the Sea")
	_human_seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.choice_log.size(), 0, "nothing to decide about an untapped permanent")


func test_two_questions_in_one_untap_step_are_served_in_order() -> void:
	# An Old Man (option) AND a Smoke (card) in the same step: two holds,
	# each answered, each answer reaching its own question.
	put_battlefield(0, "Smoke")
	var old_man := put_battlefield(0, "Old Man of the Sea")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	old_man.tapped = true
	bears.tapped = true
	giant.tapped = true
	_human_seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()
	_advance_until_held()
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.OPTION, "the Old Man first")
	assert_ok(g.answer_choice(1))   # Don't untap.
	assert_not_null(g.awaiting_choice, "then Smoke's pick")
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.CARD)
	assert_eq(g.awaiting_choice.candidates.size(), 2,
		"the Old Man, staying tapped, is not on Smoke's list")
	assert_ok(g.answer_choice("Grizzly Bears"))
	assert_null(g.awaiting_choice)
	assert_true(old_man.tapped)
	assert_false(bears.tapped)
	assert_true(giant.tapped)


func test_an_old_man_that_untaps_counts_against_smoke() -> void:
	put_battlefield(0, "Smoke")
	var old_man := put_battlefield(0, "Old Man of the Sea")
	var bears := put_battlefield(0, "Grizzly Bears")
	old_man.tapped = true
	bears.tapped = true
	_human_seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()
	_advance_until_held()
	assert_ok(g.answer_choice(0))   # Untap Old Man of the Sea.
	assert_not_null(g.awaiting_choice, "Smoke still asks — the Old Man is a candidate now")
	assert_eq(g.awaiting_choice.candidates.size(), 2)
	assert_ok(g.answer_choice("Old Man of the Sea"))
	assert_false(old_man.tapped)
	assert_true(bears.tapped, "Smoke's one untap was the Old Man")


func test_the_ai_seat_is_never_held() -> void:
	put_battlefield(0, "Smoke")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	bears.tapped = true
	giant.tapped = true
	g.agents[0] = AiPlayer.new(0)
	g.interactive_choices = true
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_null(g.awaiting_choice)
	assert_true(bears.tapped != giant.tapped, "exactly one untapped")
	assert_false(giant.tapped, "the AI keeps its bigger body")


func test_locks_are_not_double_ticked_by_a_held_step() -> void:
	# A Telekinesis-style multi-turn lock ticks ONCE per untap step even
	# when the step is re-run after a hold.
	put_battlefield(0, "Smoke")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var locked := put_battlefield(0, "Scryb Sprites")
	bears.tapped = true
	giant.tapped = true
	locked.tapped = true
	locked.skip_untaps = 2
	_human_seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()
	_advance_until_held()
	assert_eq(g.awaiting_choice.candidates.size(), 2, "the locked Sprites are not offered")
	assert_ok(g.answer_choice("Grizzly Bears"))
	assert_eq(locked.skip_untaps, 1, "ticked exactly once")
	assert_true(locked.tapped)
