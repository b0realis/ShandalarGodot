extends GameTest
## THE COUNTER'S OWN ORDER, AND THE UNLESS-COST'S X (2026-09-10,
## [member AiProfile.ranks_counters]; wave 1 row 1, `docs/forge/casting.md`
## P10).
##
## WHAT WAS WRONG, and both halves were reproduced before a line was
## written ([method AiPlayer._try_counter] at HEAD, a Wizard on eight
## Islands answering a Serra Angel):
##
##  * THE ORDER WAS THE SHUFFLE'S. The routine walked
##    `game.players[pid].hand` and cast the first card that could legally
##    answer, so a hand of `[Mana Drain, Power Sink]` spent the Drain and
##    a hand of `[Power Sink, Mana Drain]` spent the Sink on the SAME
##    board against the SAME spell. Which counter answered a threat was
##    decided by where the deck had put the cards.
##  * POWER SINK'S X WAS "AS DEEP AS THE MANA GOES". Against a caster
##    with nothing untapped the pilot paid X=7 out of eight Islands to
##    make a price of one unpayable, and had nothing left for the next
##    spell of the turn.
##
## WHAT IT IS NOW. The counters that can answer THIS spell are ranked
## before one is cast ([method AiPlayer._counter_order]) — can we pay for
## it, does it actually stop the spell, what it costs us now with its X,
## the narrow card before the wide one, and then the card we would rather
## keep — and an unless-cost's X is the smallest one the caster cannot
## pay, which is the mana they can still reach plus one.
##
## THE SENTENCE THE PLAN WROTE — *a Mana Drain on the Serra Angel and a
## Power Sink on the Bear* — is read over a GAME and not over one board,
## because only one spell is ever on the stack: the small threat comes
## first, while the caster is tapped out, and the Sink stops it for two
## mana; the Serra comes later with mana up, where the Sink is no counter
## at all and the Drain is. Both moments are pinned below, in one test.
## (The Bear itself is a figure of speech here — a Grizzly Bears prices at
## 4.0 and never clears [member AiProfile.counter_threshold] at any rung;
## a Hill Giant is the smallest threat this pilot answers.)
##
## Nothing here names a card in the AI. The unless-cost is read off the
## card's own oracle line ([method AiPlayer._unless_price], the same
## reading [method AiPlayer._is_counterspell] makes of the first one), the
## narrowness is whether the card's own [TargetSpec] carries a filter, and
## the caster's mana is the planner's own source list asked of the other
## seat.
##
## Every behaviour is pinned on the arm that has the knob and the arm that
## does not; with it off the hand is walked in its own order and the X is
## the old maximum, which is the null.


func _ai(profile: AiProfile, seat := 1) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.ranks_counters = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.ranks_counters = false
	return profile


## Seat 1 is the counter-holding pilot: [param islands] untapped Islands
## and [param counters] in hand, in that order.
func _pilot(islands: int, counters: Array) -> void:
	for _i in islands:
		put_battlefield(1, "Island")
	for card_name in counters:
		give_hand(1, card_name)


## Seat 0 casts [param card_name] with exactly the mana it costs, leaving
## [param open] untapped Mountains behind — the mana the pilot's reader
## sees when it prices an unless-cost.
func _they_cast(card_name: String, open: int) -> CardInstance:
	for _i in open:
		put_battlefield(0, "Mountain")
	var spell := give_hand(0, card_name)
	advance_to_step(Mtg.Step.MAIN1)
	var cost := spell.data.cost
	for colour in cost.colored:
		add_mana(0, int(colour), int(cost.colored[colour]))
	if cost.generic > 0:
		add_mana(0, Mtg.ManaColor.C, cost.generic)
	assert_ok(g.cast_spell(0, spell, []))
	assert_ok(g.pass_priority(0))
	return spell


## The X the pilot paid for whatever is now on top of the stack.
func _top_x() -> int:
	assert_false(g.stack.is_empty(), "nothing on the stack")
	return g.stack.back().x_value


## Is [param card_name] still in the pilot's hand?
func _still_held(card_name: String) -> bool:
	for inst in g.players[1].hand:
		if inst.data.card_name == card_name:
			return true
	return false


# ------------------------------------------------- the order was the shuffle --

func test_the_hand_order_decided_which_counter_answered() -> void:
	# THE REPRODUCTION, on the arm without the knob: same board, same
	# spell, two hands that differ only in which card was dealt first.
	var ai := _ai(_off())
	_pilot(8, ["Mana Drain", "Power Sink"])
	_they_cast("Serra Angel", 0)
	assert_string_contains(ai.act(g), "Mana Drain")

	before_each()
	var other := _ai(_off())
	_pilot(8, ["Power Sink", "Mana Drain"])
	_they_cast("Serra Angel", 0)
	assert_string_contains(other.act(g), "Power Sink",
		"the null answers with whatever the shuffle dealt first")


func test_the_ranking_does_not_care_where_the_cards_sit() -> void:
	for order in [["Mana Drain", "Power Sink"], ["Power Sink", "Mana Drain"]]:
		before_each()
		var ai := _ai(_on())
		_pilot(8, order)
		_they_cast("Serra Angel", 3)
		assert_string_contains(ai.act(g), "Mana Drain",
			"three lands up: the Sink is no counter, whatever the hand order")


func test_the_drain_takes_the_serra_and_the_sink_took_the_small_one() -> void:
	# The plan's own sentence, read over a game. First: a Hill Giant with
	# the caster tapped out — the Sink stops it for two mana and the Drain
	# stays in hand. Later: a Serra Angel with three lands up, where the
	# Sink would have to buy an X of four and the Drain is two.
	var ai := _ai(_on())
	_pilot(8, ["Mana Drain", "Power Sink"])
	var giant := _they_cast("Hill Giant", 0)
	assert_string_contains(ai.act(g), "Power Sink")
	assert_eq(_top_x(), 1, "one more than the nothing they have left")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "the giant never landed")
	assert_true(_still_held("Mana Drain"), "the hard counter is kept")

	for _i in 3:
		put_battlefield(0, "Mountain")
	var angel := give_hand(0, "Serra Angel")
	advance_to_next_turn()
	if g.active_player != 0:
		advance_to_next_turn()
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, angel, []))
	assert_ok(g.pass_priority(0))
	assert_string_contains(ai.act(g), "Mana Drain",
		"the hard counter is what is left, and what the Serra needed")


# ------------------------------------------------------- the unless-cost's X --

func test_the_sink_pays_one_more_than_they_can_reach() -> void:
	var ai := _ai(_on())
	_pilot(8, ["Power Sink"])
	_they_cast("Serra Angel", 3)
	assert_string_contains(ai.act(g), "Power Sink")
	assert_eq(_top_x(), 4, "their three lands plus one")


func test_the_sink_pays_the_old_maximum_with_the_knob_off() -> void:
	var ai := _ai(_off())
	_pilot(8, ["Power Sink"])
	_they_cast("Serra Angel", 3)
	assert_string_contains(ai.act(g), "Power Sink")
	assert_eq(_top_x(), 7, "as deep as the mana goes — eight Islands less the {U}")


func test_a_tapped_out_caster_costs_the_sink_one() -> void:
	var ai := _ai(_on())
	_pilot(8, ["Power Sink"])
	var angel := _they_cast("Serra Angel", 0)
	assert_string_contains(ai.act(g), "Power Sink")
	assert_eq(_top_x(), 1)
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD, "and it still counters")
	var untapped := 0
	for inst in g.players[1].battlefield:
		if not inst.tapped:
			untapped += 1
	assert_eq(untapped, 6, "six Islands still up, where the null left none")


func test_an_unpayable_x_out_of_reach_falls_back_to_the_maximum() -> void:
	# Nine lands across the table and three Islands here: no X we can buy
	# is a price they cannot pay, and with nothing else in hand the card
	# is still the only answer there is.
	var ai := _ai(_on())
	_pilot(3, ["Power Sink"])
	_they_cast("Serra Angel", 9)
	assert_string_contains(ai.act(g), "Power Sink")
	assert_eq(_top_x(), 2, "three Islands less the {U}")


# ------------------------------------------------ hard before an unless-cost --

func test_a_spike_they_can_pay_is_not_the_answer() -> void:
	var ai := _ai(_on())
	_pilot(8, ["Force Spike", "Counterspell"])
	_they_cast("Serra Angel", 3)
	assert_string_contains(ai.act(g), "Counterspell",
		"a printed {1} they can simply pay is no counter")
	assert_true(_still_held("Force Spike"), "the Spike is kept for a tapped-out turn")


func test_a_spike_they_cannot_pay_is_the_cheaper_answer() -> void:
	var ai := _ai(_on())
	_pilot(8, ["Force Spike", "Counterspell"])
	_they_cast("Serra Angel", 0)
	assert_string_contains(ai.act(g), "Force Spike",
		"tapped out, the one-mana card does the whole job")


func test_the_null_answers_with_whichever_came_first() -> void:
	var ai := _ai(_off())
	_pilot(8, ["Force Spike", "Counterspell"])
	_they_cast("Serra Angel", 3)
	assert_string_contains(ai.act(g), "Force Spike",
		"the null fires the Spike into three open lands")


func test_a_soft_counter_alone_is_still_cast() -> void:
	# The refusal is "not when something else answers", not "never": a
	# Spike they can pay is still the only card in hand, and what it costs
	# them is the card's own business.
	var ai := _ai(_on())
	_pilot(8, ["Force Spike"])
	_they_cast("Serra Angel", 3)
	assert_string_contains(ai.act(g), "Force Spike")


# ----------------------------------------------- narrow before wide, and paid --

func test_the_narrow_counter_goes_first() -> void:
	var ai := _ai(_on())
	_pilot(8, ["Counterspell", "Remove Soul"])
	_they_cast("Serra Angel", 3)
	assert_string_contains(ai.act(g), "Remove Soul",
		"the card that only answers creatures is spent on a creature")
	assert_true(_still_held("Counterspell"))


func test_a_counter_we_cannot_pay_for_no_longer_ends_the_search() -> void:
	# The loop RETURNS what _cast_response gives it, so a legal counter the
	# mana did not cover used to end the search with a pass. One Island, a
	# Counterspell that needs two of them, a Force Spike behind it.
	var ai := _ai(_off())
	_pilot(1, ["Counterspell", "Force Spike"])
	_they_cast("Serra Angel", 0)
	assert_eq(ai.act(g), "pass", "the null passes with an answer still in hand")

	before_each()
	var ranked := _ai(_on())
	_pilot(1, ["Counterspell", "Force Spike"])
	var angel := _they_cast("Serra Angel", 0)
	assert_string_contains(ranked.act(g), "Force Spike")
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)


# -------------------------------------------------------------- the readers --

func test_the_unless_price_is_read_off_the_oracle_line() -> void:
	assert_eq(AiPlayer._unless_price(CardRegistry.get_card("Force Spike")), 1,
		"a printed {1}")
	assert_eq(AiPlayer._unless_price(CardRegistry.get_card("Power Sink")),
		AiPlayer.UNLESS_X, "a price the counter's own caster names")
	assert_eq(AiPlayer._unless_price(CardRegistry.get_card("Counterspell")),
		AiPlayer.UNLESS_NONE, "a hard counter prints no price")
	assert_eq(AiPlayer._unless_price(CardRegistry.get_card("Mana Drain")),
		AiPlayer.UNLESS_NONE)


func test_their_open_mana_is_what_is_on_the_table() -> void:
	var ai := _ai(_on())
	assert_eq(ai._their_open_mana(g, 0), 0, "an empty board reaches nothing")
	for _i in 3:
		put_battlefield(0, "Mountain")
	assert_eq(ai._their_open_mana(g, 0), 3)
	var sol := put_battlefield(0, "Sol Ring")
	assert_eq(ai._their_open_mana(g, 0), 5, "the Ring makes two")
	g.tap_permanent(sol)
	assert_eq(ai._their_open_mana(g, 0), 3, "a tapped source reaches nothing")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_eq(ai._their_open_mana(g, 0), 5, "floating mana is mana they can reach")


# --------------------------------------------------------------- the ladder --

func test_the_rung_is_the_one_holds_instants_is_on() -> void:
	assert_false(AiProfile.apprentice().ranks_counters,
		"a seat that never counters has nothing to rank")
	assert_true(AiProfile.magician().ranks_counters)
	assert_true(AiProfile.sorcerer().ranks_counters)
	assert_true(AiProfile.wizard().ranks_counters)


func test_the_knob_is_reachable_from_the_deck_lab() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("ranks_counters=off"), "")
	assert_false(profile.ranks_counters)
	assert_eq(profile.apply_overrides("ranks_counters=on"), "")
	assert_true(profile.ranks_counters)
