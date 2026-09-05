extends GameTest
## THE TAP-TRIGGER REFUSAL (2026-09-05) — the residue the X-seam pass of
## the day before named and did not close.
##
## `AiPlayer` taps its lands BEFORE it announces the spell they pay for.
## A TAP-TRIGGERED ability — Manabarbs, Psychic Venom, Blight — therefore
## goes on the stack in the middle of paying, and CR 601.2a's sorcery
## timing refuses the spell for a stack that WAS empty when the planner
## asked `cast_refusal` about it. The refusal is real, but it is
## transient: the mana stays in the pool until the step ends (CR 500.4),
## the trigger resolves one priority round later, and the same cast can
## be made from the floating mana without tapping a second land.
##
## Before this pass the card went into the refusal memo and stayed there
## for the rest of the step, so the AI paid the life the trigger charged,
## lost the mana at the step boundary, and never played the card —
## 1,143 of the 1,271 refused casts in the X-seam pass's 258-deck census.
##
## These tests state the SITUATION and what the seat must end up doing.


func _wizard() -> AiPlayer:
	return AiPlayer.new(0, AiProfile.wizard())


## Seat 0's AI drives; seat 1 just passes. Runs at most [param rounds]
## priority rounds and stops early once seat 0 has nothing more to do.
func _drive(ai: AiPlayer, rounds := 12) -> void:
	for _i in rounds:
		if g.game_over:
			return
		var did := ai.act(g)
		if g.priority_player == 1:
			g.pass_priority(1)
		if did == "" and g.stack.is_empty():
			return


func _battlefield_names(pid: int) -> Array:
	var out: Array = []
	for inst in g.players[pid].battlefield:
		out.append(inst.data.card_name)
	return out


func _untapped_lands(pid: int) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.is_land() and not inst.tapped:
			n += 1
	return n


# ------------------------------------------------- the reproduced board --

## THE BUG, stated as a board. Four Mountains, a Hill Giant in hand, and
## a Manabarbs across the table: paying for the Giant puts four triggers
## on the stack and the engine refuses the Giant for a non-empty stack.
func test_a_tap_trigger_does_not_cost_the_turn_its_cast() -> void:
	var ai := _wizard()
	for _i in 4:
		put_battlefield(0, "Mountain")
	put_battlefield(1, "Manabarbs")
	var giant := give_hand(0, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	var turn := g.turn_number
	_drive(ai)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD,
		"the Giant never reached the table: %s" % str(_battlefield_names(0)))
	assert_eq(g.turn_number, turn, "and it did so on the same turn")


## The FIRST act is not a pass and not a cast: the lands are tapped, the
## triggers are on the stack, and the seat says so rather than giving up.
func test_the_first_action_holds_the_card_rather_than_refusing_it() -> void:
	var ai := _wizard()
	for _i in 4:
		put_battlefield(0, "Mountain")
	put_battlefield(1, "Manabarbs")
	give_hand(0, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_string_contains(did, "holds Hill Giant")
	assert_false(g.stack.is_empty(), "the tap triggers are on the stack")
	assert_false(ai._refused.has(str(g.players[0].hand[0].id)),
		"a refusal the planner can wait out must not enter the memo")


## The retry spends the FLOATING mana. Tapping again would be a second
## helping of Manabarbs damage for the same spell — and there is nothing
## left to tap here anyway, which is what makes the point checkable.
func test_the_retry_taps_no_second_land() -> void:
	var ai := _wizard()
	for _i in 6:
		put_battlefield(0, "Mountain")
	put_battlefield(1, "Manabarbs")
	var giant := give_hand(0, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(ai)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "the Giant was cast")
	assert_eq(_untapped_lands(0), 2,
		"exactly the four lands the Giant costs were tapped")
	assert_eq(g.players[0].life, 16, "and Manabarbs was paid exactly four times")


## The whole board, unchanged, with the enchantment gone: the seat casts
## on its FIRST action, so nothing above is a change to the normal path.
func test_without_the_trigger_the_cast_happens_immediately() -> void:
	var ai := _wizard()
	for _i in 4:
		put_battlefield(0, "Mountain")
	var giant := give_hand(0, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_eq(did, "cast Hill Giant")
	assert_eq(giant.zone, Mtg.Zone.STACK)


## Psychic Venom is the other shape the census named: the trigger is on
## the LAND rather than global, so it fires once and only for that land.
func test_psychic_venom_on_our_own_land_is_waited_out_too() -> void:
	var ai := _wizard()
	var lands: Array = []
	for _i in 6:
		lands.append(put_battlefield(0, "Forest"))
	var venom := give_hand(1, "Psychic Venom")
	g.attach_aura_from_anywhere(venom, lands[0], 1)
	var wurm := give_hand(0, "Craw Wurm")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(ai)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, "the Wurm reached the table")
	assert_eq(g.players[0].life, 18, "and the Venom stung exactly once")


# --------------------------------------- the refusals that DO still stand --

## The memo is not switched off — only taught to tell the two apart. With
## an empty stack the classifier says "this one stands", which is the
## branch that keeps the planner from tapping for the same card twice.
func test_an_empty_stack_means_the_refusal_stands() -> void:
	var ai := _wizard()
	var giant := give_hand(0, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(g.stack.is_empty())
	assert_false(ai._wait_out(g, giant),
		"nothing to wait for: this refusal is the planner's own mistake")


## And a second helping of the same board does not loop: once the Giant
## is cast the seat stops, rather than holding a card it has already
## played. (A deferral that could repeat forever would show up here as a
## driver that never returns.)
func test_the_deferral_does_not_repeat_once_the_cast_lands() -> void:
	var ai := _wizard()
	for _i in 4:
		put_battlefield(0, "Mountain")
	put_battlefield(1, "Manabarbs")
	give_hand(0, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(ai, 30)
	var holds := 0
	for line in g.log_lines:
		if line.contains("(AI holds "):
			holds += 1
	assert_eq(holds, 1, "the card is held exactly once, then cast")
