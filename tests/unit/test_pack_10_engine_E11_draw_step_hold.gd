extends GameTest
## Pack 10 E11 — THE DRAW STEP'S QUESTIONS, HELD FOR A HUMAN. The draw
## step's draw is a turn-based action (CR 504.1): a question one of its
## replacements asks (Island Sanctuary's "skip that draw?", Fasting's "skip
## that step?", Abundance's land or nonland and its bottom order, the CR
## 616.1 order between two replacements) has no stack item for the
## pre-flight. MtgGame._hold_draw_step probes the step over a snapshot and
## holds it on the first question a human seat has not answered; each
## answer is parked and the step entered again (the ROADMAP row "A draw
## replacement asks OUTSIDE a resolution").


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-10", false)


func _human(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


## Pass until a question holds the duel, or turn [param turn]'s first main
## phase is reached.
func _advance_until_held(turn: int) -> void:
	var guard := 0
	while g.awaiting_choice == null and not g.game_over and guard < 400 \
			and not (g.turn_number == turn and g.current_step() == Mtg.Step.MAIN1):
		_advance_once()
		guard += 1


# ====================================================== Island Sanctuary --

func test_island_sanctuary_holds_a_human_in_the_draw_step() -> void:
	put_battlefield(0, "Island Sanctuary")
	var human := _human(0)
	advance_to_next_turn()   # the opponent's turn 2
	var hand := g.players[0].hand.size()
	_advance_until_held(3)
	assert_not_null(g.awaiting_choice, "held")
	if g.awaiting_choice == null: return
	assert_eq(g.turn_number, 3)
	assert_eq(g.current_step(), Mtg.Step.DRAW, "held IN the draw step")
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.YES_NO)
	assert_eq(g.awaiting_choice.pid, 0)
	assert_eq(g.awaiting_choice.source, MtgGame.DRAW_STEP_SOURCE)
	assert_eq(g.awaiting_choice.prompt, "Select draw potential.")
	assert_false(g.awaiting_choice.is_cost, "a turn-based action, not a cost")
	assert_eq(g.players[0].hand.size(), hand, "nothing drawn while held")
	assert_refused(g.pass_priority(0), "waiting for a choice")
	assert_refused(g.cancel_choice(), "must be answered")
	assert_ok(g.answer_choice(true))
	assert_null(g.awaiting_choice)
	assert_eq(g.players[0].hand.size(), hand, "the player skipped the draw")
	assert_eq(g.current_step(), Mtg.Step.DRAW, "and the step goes on, with priority")
	assert_eq(g.unanswered_choices.size(), 0, "the player answered: nothing decided for them")
	assert_false(human.has_parked(), "the answer was spent")


func test_island_sanctuary_answered_no_draws_the_card() -> void:
	put_battlefield(0, "Island Sanctuary")
	_human(0)
	advance_to_next_turn()
	var hand := g.players[0].hand.size()
	_advance_until_held(3)
	assert_not_null(g.awaiting_choice)
	if g.awaiting_choice == null: return
	assert_ok(g.answer_choice(false))
	assert_eq(g.players[0].hand.size(), hand + 1, "drawn")
	assert_eq(g.players[0].drawn_this_turn.size(), 1)


func test_a_heuristic_seat_is_never_held() -> void:
	put_battlefield(0, "Island Sanctuary")
	g.interactive_choices = true   # the seat itself does not want to be asked
	advance_to_next_turn()
	_advance_until_held(3)
	assert_null(g.awaiting_choice)
	assert_eq(g.turn_number, 3)
	assert_eq(g.current_step(), Mtg.Step.MAIN1)


func test_a_human_with_no_draw_replacement_draws_as_ever() -> void:
	_human(0)
	advance_to_next_turn()
	var hand := g.players[0].hand.size()
	_advance_until_held(3)
	assert_null(g.awaiting_choice, "nothing could ask, so nothing is probed or held")
	assert_eq(g.players[0].hand.size(), hand + 1)


func test_the_opponents_draw_step_does_not_hold_the_sanctuarys_owner() -> void:
	put_battlefield(0, "Island Sanctuary")   # P0's: it offers itself for P0's draws only
	_human(0)
	var hand := g.players[1].hand.size()
	_advance_until_held(2)
	assert_null(g.awaiting_choice)
	assert_eq(g.players[1].hand.size(), hand + 1)


# ================================================================ Fasting --

func test_fasting_holds_a_human_on_skipping_the_step() -> void:
	var fasting := put_battlefield(0, "Fasting")
	_human(0)
	advance_to_next_turn()
	var hand := g.players[0].hand.size()
	_advance_until_held(3)
	assert_not_null(g.awaiting_choice)
	if g.awaiting_choice == null: return
	assert_eq(g.current_step(), Mtg.Step.DRAW)
	assert_string_contains(g.awaiting_choice.prompt, "Skip your draw step")
	var life := g.players[0].life
	assert_ok(g.answer_choice(true))
	assert_eq(g.players[0].life, life + 2)
	assert_eq(g.players[0].hand.size(), hand, "no draw")
	assert_eq(g.current_step(), Mtg.Step.MAIN1, "the skipped step happened not at all")
	assert_eq(fasting.zone, Mtg.Zone.BATTLEFIELD)


# ========================================== Abundance: two questions in a row --

func _stack_library(pid: int, top_first: Array) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in range(top_first.size() - 1, -1, -1):
		var card := give_hand(pid, String(top_first[i]))
		g.put_from_hand_on_top_of_library(card)
		out.push_front(card)
	return out


func test_abundance_holds_each_of_its_questions_in_turn() -> void:
	CardPacks.set_enabled("pack-10", true)
	put_battlefield(0, "Abundance")
	_human(0)
	advance_to_next_turn()
	var top := _stack_library(0, ["Grizzly Bears", "Hill Giant", "Forest"])
	var bears := top[0]
	var giant := top[1]
	var forest := top[2]
	_advance_until_held(3)
	assert_not_null(g.awaiting_choice, "held on Abundance's choice")
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.OPTION)
	assert_string_contains(g.awaiting_choice.prompt, "Abundance")
	assert_ok(g.answer_choice(1))   # reveal until a land
	assert_not_null(g.awaiting_choice, "held again: the order of the two on the bottom")
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.CARD)
	assert_eq(g.current_step(), Mtg.Step.DRAW)
	assert_eq(forest.zone, Mtg.Zone.LIBRARY, "still nothing has happened")
	assert_ok(g.answer_choice(bears.id))
	assert_null(g.awaiting_choice)
	assert_eq(forest.zone, Mtg.Zone.HAND, "the land revealed went to the hand")
	var library := g.players[0].library
	assert_eq(library[1], bears, "the Bears went to the bottom first")
	assert_eq(library[0], giant, "and the Giant beneath it")
	assert_eq(g.players[0].drawn_this_turn.size(), 0, "a replaced draw is no draw")


func test_two_replacements_hold_the_order_question_first() -> void:
	CardPacks.set_enabled("pack-10", true)
	put_battlefield(0, "Island Sanctuary")
	put_battlefield(0, "Abundance")
	_human(0)
	advance_to_next_turn()
	var hand := g.players[0].hand.size()
	_advance_until_held(3)
	assert_not_null(g.awaiting_choice)
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.prompt, "Which replacement applies to your draw first?")
	var index: int = g.awaiting_choice.options.find("Island Sanctuary")
	assert_true(index >= 0)
	assert_ok(g.answer_choice(index))
	assert_not_null(g.awaiting_choice, "then the Sanctuary's own question")
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.prompt, "Select draw potential.")
	assert_ok(g.answer_choice(true))
	assert_null(g.awaiting_choice)
	assert_eq(g.players[0].hand.size(), hand, "skipped (CR 616.1: the player's order)")
