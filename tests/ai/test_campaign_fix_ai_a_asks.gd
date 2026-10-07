extends GameTest
## THE WHOLE-GAME CAMPAIGN, fix-ai-a: THE QUESTIONS A CARD ASKS
## (2026-10-07), the AI side of two findings whose card side is fix-cards':
##  * w2-7 "Sacrifice this unless ANY player pays {3}" (Icy Prison) asks
##    both seats, and the prisoner's own controller paid to keep its
##    creature exiled. The card's hint is now per player (fix-cards); the
##    AI answers a keep offer about a permanent across the table with that
##    hint — the contract tests/ai/test_ai_prices_offers_2026_09_11.gd
##    pins — so the Prison goes when its own controller cannot pay.
##  * w1-3 A card that pre-sorts its candidates and says so
##    ([member PlayerChoice.ordered]) is answered with its first: Drop of
##    Honey's tie destroys their creature, not ours.
## Each with a hidden-hand permutation (docs/fair-play.md).


func before_each() -> void:
	CardPacks.set_enabled("pack-3", true)   # Ice Age: Icy Prison
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-3", false)


func _ai(seat: int, forecasts := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.forecasts_tactics = forecasts
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


const KEEP := "Pay {3} to keep Icy Prison?"


## The per-player hint is the answer for a permanent across the table.
func test_a_keep_offer_across_the_table_takes_the_hint() -> void:
	put_battlefield(0, "Icy Prison")
	for n in 3: put_battlefield(1, "Forest")
	var ai := _ai(1)
	advance_to_next_turn()
	assert_false(ai.answer_yes_no(g, 1, KEEP, false))
	assert_true(ai.answer_yes_no(g, 1, KEEP, true))


## End to end through the card (its upkeep trigger, both seats asked).
func test_the_prison_is_sacrificed_when_its_controller_cannot_pay() -> void:
	var wurm := put_battlefield(1, "Craw Wurm")
	var prison := put_battlefield(0, "Icy Prison")
	resolve_stack()
	if wurm.zone != Mtg.Zone.EXILE:
		g.exile_permanent(wurm)
	_ai(1)
	for n in 3: put_battlefield(1, "Forest")
	advance_to_next_turn()      # P1's turn
	advance_to_next_turn()      # P0's upkeep — P0 has no mana
	resolve_stack()
	var tapped := 0
	for i in g.players[1].battlefield:
		if i.is_land() and i.tapped: tapped += 1
	assert_eq(tapped, 0, "P1 tapped its Forests for the Prison's {3}")
	assert_eq(prison.zone, Mtg.Zone.GRAVEYARD)


func test_their_hidden_hand_does_not_change_the_keep_answer() -> void:
	var zones: Array = []
	for hand in [[], ["Icy Prison"], ["Counterspell", "Giant Growth"]]:
		before_each()
		var wurm := put_battlefield(1, "Craw Wurm")
		var prison := put_battlefield(0, "Icy Prison")
		resolve_stack()
		if wurm.zone != Mtg.Zone.EXILE:
			g.exile_permanent(wurm)
		for card_name in hand:
			give_hand(0, String(card_name))
		_ai(1)
		for n in 3: put_battlefield(1, "Forest")
		advance_to_next_turn()
		advance_to_next_turn()
		resolve_stack()
		zones.append(prison.zone)
	assert_eq(zones, [Mtg.Zone.GRAVEYARD, Mtg.Zone.GRAVEYARD, Mtg.Zone.GRAVEYARD])


# ---------------------------------------------------------- w1-3 ordered --

## The contract: an ORDERED ask is answered with its first candidate, not
## the most valuable one.
func test_an_ordered_ask_is_answered_with_its_first_candidate() -> void:
	var ai := _ai(0)
	var low := put_battlefield(1, "Llanowar Elves")
	var high := put_battlefield(1, "Serra Angel")
	var cands: Array[CardInstance] = [low, high]
	assert_eq(ai.choose_card(g, 0, cands, "Choose one", false, false, true), low)
	assert_eq(ai.choose_card(g, 0, cands, "Choose one"), high, "unordered: the most valuable")


func test_drop_of_honey_eats_their_tied_creature() -> void:
	_ai(1)
	put_battlefield(1, "Drop of Honey")
	var wall := put_battlefield(1, "Wall of Stone")     # 0/8, ours
	var thopter := put_battlefield(0, "Ornithopter")    # 0/2, theirs
	put_battlefield(1, "Craw Wurm")
	var guard := 0
	while not g.game_over and guard < 600 and not (g.active_player == 1
			and g.turn_number > 1 and g.current_step() == Mtg.Step.UPKEEP
			and not g.stack.is_empty()):
		_advance_once()
		guard += 1
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD, "our Wall fed to our own Drop of Honey")
	assert_eq(thopter.zone, Mtg.Zone.GRAVEYARD)
