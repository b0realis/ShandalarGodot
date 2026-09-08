extends GameTest
## §1.5 / §6.2 of docs/duel-todo.md — THE MULLIGAN, which since 2026-09-08
## is the PARIS one, on the owner's word: *"After each mulligan you draw
## one card less (up to seven mulligans where you start with empty hand).
## If you have no lands or all lands in hand, the ai or human decision to
## take mulligan is almost automatic - no special rules needed."*
##
## So: ANY hand may go back, each redraw is ONE CARD FEWER, the question
## returns to the smaller hand until its owner keeps, and a keep is final.
## `[QoL]` — the 1997 game's own rule (`Duel.hlp`, **Mulligan**: one
## redraw of seven for seven, and only of a hand with no land or nothing
## but land) is quoted in `MtgGame` above `take_mulligan`, and is not the
## rule any more. The no-land / all-land test survives as the NAME of the
## hand ([method MtgGame.hand_is_a_mulligan_hand]) and the plain agent's
## reason to redraw. And `Duel.hlp`, **Play or Draw Rule**, still: the
## toss winner chooses, and whoever plays first skips their first draw.

const SPELLS := "Grizzly Bears"
const LAND := "Forest"


func _deal(deck0: Array, deck1: Array, seed_value := 424242) -> void:
	g = MtgGame.new()
	g.setup(deck0, deck1, "P0", "P1", 20, 20, seed_value)
	g.deal_opening_hands(7)


func _deck(land_count: int, spell_count: int) -> Array:
	var out: Array = []
	for i in land_count:
		out.append(LAND)
	for i in spell_count:
		out.append(SPELLS)
	return out


func _lands_in_hand(pid: int) -> int:
	var lands := 0
	for inst in g.players[pid].hand:
		if inst.is_land():
			lands += 1
	return lands


# ============================================================ the offer --

func test_any_hand_may_be_thrown_back() -> void:
	_deal(_deck(15, 15), _deck(15, 15))
	var lands := _lands_in_hand(0)
	assert_gt(lands, 0, "fixture check: the hand is mixed")
	assert_lt(lands, 7, "fixture check: the hand is mixed")
	assert_true(g.may_mulligan(0), "an ordinary hand may go back — the owner's rule")
	assert_true(g.may_mulligan(1))


func test_the_1997_names_still_name_the_hand() -> void:
	_deal(_deck(30, 0), _deck(0, 30))
	assert_true(g.hand_is_a_mulligan_hand(0), "seven lands")
	assert_true(g.hand_is_a_mulligan_hand(1), "no land at all")
	_deal(_deck(15, 15), _deck(15, 15))
	assert_false(g.hand_is_a_mulligan_hand(0), "a mixed hand is neither")


func test_the_redraw_is_one_card_fewer_and_shuffles_the_hand_back() -> void:
	_deal(_deck(30, 0), _deck(15, 15))
	var before: Array[int] = []
	for inst in g.players[0].hand:
		before.append(inst.id)
	assert_eq(g.players[0].library.size(), 23)
	assert_ok(g.take_mulligan(0))
	assert_eq(g.players[0].hand.size(), 6, "seven back, six out")
	assert_eq(g.players[0].library.size(), 24, "the old hand went back in")
	for id in before:
		var zone: int = g.find_instance(id).zone
		assert_true(zone == Mtg.Zone.LIBRARY or zone == Mtg.Zone.HAND)
	assert_eq(g.mulligans_taken[0], 1)
	assert_true(g.has_mulliganed(0))
	assert_false(g.has_mulliganed(1))


func test_the_question_comes_back_to_the_smaller_hand() -> void:
	_deal(_deck(30, 0), _deck(15, 15))
	assert_ok(g.take_mulligan(0))
	assert_true(g.may_mulligan(0), "six may go back too")
	assert_ok(g.take_mulligan(0))
	assert_eq(g.players[0].hand.size(), 5)
	assert_eq(g.mulligans_taken[0], 2)


func test_seven_mulligans_end_in_an_empty_hand_and_no_eighth() -> void:
	_deal(_deck(30, 0), _deck(15, 15))
	for expected in [6, 5, 4, 3, 2, 1, 0]:
		assert_true(g.may_mulligan(0))
		assert_ok(g.take_mulligan(0))
		assert_eq(g.players[0].hand.size(), expected)
	assert_eq(g.mulligans_taken[0], 7)
	assert_eq(g.players[0].library.size(), 30, "every card is back in the library")
	assert_false(g.may_mulligan(0), "nothing is left to throw back")
	assert_refused(g.take_mulligan(0), "mulligan")


func test_a_keep_is_final() -> void:
	_deal(_deck(30, 0), _deck(30, 0))
	assert_ok(g.decline_mulligan(0))
	assert_false(g.may_mulligan(0), "kept")
	assert_refused(g.take_mulligan(0), "mulligan")
	assert_ok(g.take_mulligan(1))
	assert_false(g.may_mulligan(0), "and the opponent's redraw does not reopen it")
	assert_true(g.may_mulligan(1), "while the other seat is still deciding")


func test_the_seats_are_independent() -> void:
	_deal(_deck(30, 0), _deck(15, 15))
	assert_ok(g.take_mulligan(0))
	assert_ok(g.take_mulligan(0))
	assert_eq(g.players[1].hand.size(), 7, "the other hand is untouched")
	assert_ok(g.take_mulligan(1))
	assert_eq(g.players[1].hand.size(), 6)
	assert_eq(g.players[0].hand.size(), 5)


func test_the_refusals_are_worded() -> void:
	_deal(_deck(15, 15), _deck(15, 15))
	assert_eq(g.take_mulligan(5), "no such player")
	assert_eq(g.decline_mulligan(5), "no such player")
	g.start_duel(0)
	assert_eq(g.decline_mulligan(0), "the opening hand is already settled")
	assert_string_contains(g.take_mulligan(0), "no mulligan is available to P0")


func test_the_log_carries_the_count() -> void:
	_deal(_deck(30, 0), _deck(15, 15))
	assert_ok(g.take_mulligan(0))
	assert_ok(g.decline_mulligan(1))
	var text := "\n".join(g.log_lines)
	assert_string_contains(text, "P0 has chosen to take a mulligan, drawing 6")
	assert_string_contains(text, "P1 did not take a mulligan")


# ======================================================== the duel begins --

func test_the_duel_starts_after_the_opening_hands() -> void:
	_deal(_deck(15, 15), _deck(15, 15))
	g.start_duel(1)
	assert_false(g.may_mulligan(0), "the opening-hand phase is over")
	assert_false(g.mulligan_open)
	assert_eq(g.active_player, 1)
	assert_eq(g.turn_number, 1)
	# Play or Draw: whoever plays first does not draw on turn one.
	var hand_before := g.players[1].hand.size()
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.players[1].hand.size(), hand_before,
		"the player who plays first skips their first draw")


func test_a_mulliganed_seat_plays_on_with_its_smaller_hand() -> void:
	_deal(_deck(15, 15), _deck(15, 15))
	assert_ok(g.take_mulligan(0))
	assert_ok(g.take_mulligan(0))
	g.start_duel(1)
	assert_eq(g.players[0].hand.size(), 5)
	advance_to_step(Mtg.Step.MAIN1)
	# Seat 0's own turn: the ordinary draw, on top of the five.
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	assert_eq(g.players[0].hand.size(), 6, "five kept, one drawn")


func test_a_second_deal_resets_the_count() -> void:
	_deal(_deck(30, 0), _deck(15, 15))
	assert_ok(g.take_mulligan(0))
	assert_ok(g.decline_mulligan(1))
	g.deal_opening_hands(7)
	assert_eq(g.mulligans_taken, [0, 0])
	assert_eq(g.mulligan_kept, [false, false])
	assert_true(g.may_mulligan(1))


# ======================================================== the plain agent --

func test_the_default_agent_redraws_a_1997_hand_but_not_a_fine_one() -> void:
	_deal(_deck(30, 0), _deck(15, 15))
	assert_true(g.agents[0].choose_mulligan(g, 0), "all land goes back")
	assert_false(g.agents[1].choose_mulligan(g, 1), "a mixed hand is kept")
	_deal(_deck(0, 30), _deck(15, 15))
	assert_true(g.agents[0].choose_mulligan(g, 0), "no land goes back")


func test_the_default_agent_stops_at_the_floor() -> void:
	# An all-land deck deals an all-land hand every time; the plain rule
	# would throw them back for ever, so it keeps at MULLIGAN_FLOOR.
	_deal(_deck(30, 0), _deck(15, 15))
	var taken := 0
	while g.may_mulligan(0) and g.agents[0].choose_mulligan(g, 0):
		assert_ok(g.take_mulligan(0))
		taken += 1
	assert_eq(g.players[0].hand.size(), DecisionAgent.MULLIGAN_FLOOR)
	assert_eq(taken, 7 - DecisionAgent.MULLIGAN_FLOOR)
	assert_eq(DecisionAgent.MULLIGAN_FLOOR, AiMulligan.FLOOR,
		"the same floor for the same reason")


func test_start_still_deals_and_begins_in_one_call() -> void:
	# Every existing caller (the Deck Lab, every headless test) uses this.
	g = MtgGame.new()
	g.setup(_deck(30, 0), _deck(30, 0), "P0", "P1", 20, 20, 7)
	g.start(7, 0)
	assert_eq(g.players[0].hand.size(), 7)
	assert_eq(g.turn_number, 1)
	assert_false(g.may_mulligan(0))
