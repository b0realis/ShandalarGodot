extends GameTest
## §1.1 of docs/duel-todo.md — THE PLAYER CHOOSES THEIR OWN DISCARD.
##
## The 1997 game made this a named phase of its own: `@PROMPT_DISCARD`
## (Program/UIStrings.txt:1074) is `Paused: Discard phase` and
## `@PROMPT_DISCARDACARD` (:1106) opens with `Select card to discard.` —
## the phase bar even carries a dedicated discard icon. Our cleanup step
## used to hand the whole decision to `DecisionAgent.choose_discard`.
##
## The engine now PAUSES for any seat whose agent says it wants to be asked
## (`DecisionAgent.wants_to_choose_discard`), exactly the way it already
## pauses for attackers and blockers. Seats that do not — the AI, the
## default heuristic agent, every headless test — are unchanged.


## A seat that insists on choosing for itself, the way HumanAgent does.
class PromptAgent extends DecisionAgent:
	func wants_to_choose_discard() -> bool:
		return true


func _fill_hand(pid: int, count: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in count:
		out.append(give_hand(pid, "Grizzly Bears"))
	return out


func test_a_heuristic_seat_still_discards_by_itself() -> void:
	_fill_hand(0, 9)
	advance_to_next_turn()
	assert_false(g.awaiting_discard, "the default agent never pauses the turn")
	assert_eq(g.players[0].hand.size(), 7)


func test_an_interactive_seat_pauses_the_cleanup() -> void:
	g.agents[0] = PromptAgent.new()
	var hand := _fill_hand(0, 9)
	advance_to_step(Mtg.Step.CLEANUP)
	assert_true(g.awaiting_discard, "the duel stops at the discard phase")
	assert_eq(g.discard_count, 2, "two over the maximum hand size")
	assert_eq(g.players[0].hand.size(), 9, "nothing has been discarded yet")
	assert_eq(g.turn_number, 1, "and the turn has not passed")
	# Nothing else may happen while the phase waits (CR 514.1 — no priority).
	assert_refused(g.pass_priority(0), "discard")
	assert_ok(g.discard_to_hand_size(0, [hand[3], hand[7]]))
	assert_false(g.awaiting_discard)
	assert_eq(g.players[0].hand.size(), 7)
	assert_eq(hand[3].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(hand[7].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.turn_number, 2, "cleanup finished and the turn passed")


func test_the_discard_must_be_exactly_the_right_cards() -> void:
	g.agents[0] = PromptAgent.new()
	var hand := _fill_hand(0, 9)
	var theirs := give_hand(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.CLEANUP)
	assert_refused(g.discard_to_hand_size(0, [hand[0]]), "2")
	assert_refused(g.discard_to_hand_size(0, [hand[0], hand[0]]), "twice")
	assert_refused(g.discard_to_hand_size(0, [hand[0], theirs]), "not in your hand")
	assert_refused(g.discard_to_hand_size(1, [hand[0], hand[1]]), "only the active player")
	assert_true(g.awaiting_discard, "a refusal leaves the phase where it was")
	assert_ok(g.discard_to_hand_size(0, [hand[0], hand[1]]))


func test_the_rest_of_cleanup_still_happens_after_the_choice() -> void:
	g.agents[0] = PromptAgent.new()
	var hand := _fill_hand(0, 8)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.spells_cast_this_turn[0].size(), 1)
	advance_to_step(Mtg.Step.CLEANUP)
	assert_true(g.awaiting_discard)
	assert_ok(g.discard_to_hand_size(0, [hand[0]]))
	assert_eq(g.spells_cast_this_turn[0].size(), 0,
		"the per-turn bookkeeping the rest of cleanup does still ran")
	assert_eq(g.turn_number, 2)


func test_no_pause_when_the_hand_is_legal() -> void:
	g.agents[0] = PromptAgent.new()
	_fill_hand(0, 5)
	advance_to_next_turn()
	assert_false(g.awaiting_discard)
	assert_eq(g.discard_count, 0)
