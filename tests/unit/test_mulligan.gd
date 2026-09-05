extends GameTest
## §1.5 / §6.2 of docs/duel-todo.md — THE SHANDALAR MULLIGAN.
##
## `Duel.hlp`, topic **Mulligan**, verbatim: *"To begin a duel, both
## players draw seven cards to fill their initial hands. If either player
## draws no land in this seven cards or draws all land, then that player
## has the option to declare a mulligan. There is no requirement to declare
## a mulligan; it is entirely the decision of the affected duelist. If
## either player declares a mulligan, that player must shuffle her hand
## back into her library and draw seven new cards to make an initial hand.
## The other player has the option to do so as well… If either player draws
## a mulligan hand a second time, that's just too bad. Each player has only
## one chance to redraw, and once that's used or waived, the duel begins."*
##
## So: SEVEN FOR SEVEN, no bottoming, no scaling count — not Paris and not
## London, and nothing like s30's. And `Duel.hlp`, **Play or Draw Rule**:
## the toss winner chooses, and whoever plays first skips their first draw.

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


func test_an_all_land_hand_may_redraw() -> void:
	_deal(_deck(30, 0), _deck(15, 15))
	assert_true(g.may_mulligan(0), "seven lands is a mulligan hand")


func test_a_no_land_hand_may_redraw() -> void:
	_deal(_deck(0, 30), _deck(15, 15))
	assert_true(g.may_mulligan(0), "no land at all is a mulligan hand")


func test_an_ordinary_hand_may_not() -> void:
	_deal(_deck(15, 15), _deck(15, 15))
	var lands := 0
	for inst in g.players[0].hand:
		if inst.is_land():
			lands += 1
	assert_gt(lands, 0, "fixture check: the hand is mixed")
	assert_lt(lands, 7, "fixture check: the hand is mixed")
	assert_false(g.may_mulligan(0), "only 0-land and all-land hands qualify")


func test_the_redraw_is_seven_for_seven_and_shuffles_the_hand_back() -> void:
	_deal(_deck(30, 0), _deck(15, 15))
	var before: Array[int] = []
	for inst in g.players[0].hand:
		before.append(inst.id)
	assert_eq(g.players[0].library.size(), 23)
	assert_ok(g.take_mulligan(0))
	assert_eq(g.players[0].hand.size(), 7, "seven for seven — never six")
	assert_eq(g.players[0].library.size(), 23, "the old hand went back in")
	for id in before:
		assert_eq(g.find_instance(id).zone == Mtg.Zone.LIBRARY
			or g.find_instance(id).zone == Mtg.Zone.HAND, true)


func test_each_player_has_only_one_chance() -> void:
	_deal(_deck(30, 0), _deck(15, 15))
	assert_ok(g.take_mulligan(0))
	assert_false(g.may_mulligan(0), "'Each player has only one chance to redraw'")
	assert_refused(g.take_mulligan(0), "mulligan")


func test_the_other_player_may_follow_even_with_a_fine_hand() -> void:
	_deal(_deck(30, 0), _deck(15, 15))
	assert_false(g.may_mulligan(1), "not on their own hand's account")
	assert_ok(g.take_mulligan(0))
	assert_true(g.may_mulligan(1), "'The other player has the option to do so as well'")
	assert_ok(g.take_mulligan(1))
	assert_false(g.may_mulligan(1))


func test_waiving_the_chance_spends_it() -> void:
	_deal(_deck(30, 0), _deck(30, 0))
	assert_ok(g.decline_mulligan(0))
	assert_false(g.may_mulligan(0), "'once that's used or waived, the duel begins'")
	assert_ok(g.take_mulligan(1))
	assert_false(g.may_mulligan(0), "a waiver is not undone by the opponent's redraw")


func test_the_duel_starts_after_the_opening_hands() -> void:
	_deal(_deck(15, 15), _deck(15, 15))
	g.start_duel(1)
	assert_false(g.may_mulligan(0), "the opening-hand phase is over")
	assert_eq(g.active_player, 1)
	assert_eq(g.turn_number, 1)
	# Play or Draw: whoever plays first does not draw on turn one.
	var hand_before := g.players[1].hand.size()
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.players[1].hand.size(), hand_before,
		"the player who plays first skips their first draw")


func test_the_default_agent_redraws_a_mulligan_hand_but_not_a_fine_one() -> void:
	_deal(_deck(30, 0), _deck(15, 15))
	assert_true(g.agents[0].choose_mulligan(g, 0, true))
	assert_false(g.agents[1].choose_mulligan(g, 1, false),
		"the courtesy redraw is declined when the hand is fine")


func test_start_still_deals_and_begins_in_one_call() -> void:
	# Every existing caller (the Deck Lab, every headless test) uses this.
	g = MtgGame.new()
	g.setup(_deck(30, 0), _deck(30, 0), "P0", "P1", 20, 20, 7)
	g.start(7, 0)
	assert_eq(g.players[0].hand.size(), 7)
	assert_eq(g.turn_number, 1)
	assert_false(g.may_mulligan(0))
