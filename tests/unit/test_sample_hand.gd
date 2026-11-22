extends GutTest
## [QoL] The deck builder's sample hand — the model behind the Stats
## window's Hand page.
##
## THE RULES ARE THE DUEL'S, and that is what these tests hold it to: the
## deal is a permutation of the main deck, the mulligan is the Paris
## rule the engine plays since 2026-09-08 (one card fewer each time,
## down to nothing, never refused while a hand is left), the no-land /
## all-land test is the 1997 rule's advice and an empty hand is neither,
## and a seed deals the same hand twice.


var deck: DeckModel


func before_each() -> void:
	CardRegistry.ensure_loaded()
	deck = DeckModel.new()


func _fill(card_name: String, n: int) -> void:
	for i in range(n):
		deck.add(card_name)


func _sorted(names: Array[String]) -> Array[String]:
	var out := names.duplicate()
	out.sort()
	return out


# ------------------------------------------------------------- the deal --

func test_a_deal_is_seven_off_a_shuffled_copy_of_the_main_deck() -> void:
	_fill("Swamp", 20)
	_fill("Grizzly Bears", 20)
	var sample := SampleHand.new(deck)
	assert_eq(sample.deck_size(), 40, "every copy is a card")
	assert_eq(sample.hand.size(), 0, "nothing is dealt until asked")
	sample.new_hand()
	assert_eq(sample.hand.size(), 7, "seven")
	assert_eq(sample.library_size(), 33, "and the rest is the library")
	assert_eq(sample.turn, 1)
	assert_eq(sample.mulligans, 0)
	var everything: Array[String] = []
	everything.append_array(sample.hand)
	everything.append_array(sample.library)
	var expected: Array[String] = []
	for i in 20:
		expected.append("Swamp")
		expected.append("Grizzly Bears")
	assert_eq(_sorted(everything), _sorted(expected),
		"hand and library together are the deck, no card made or lost")


func test_the_sideboard_is_not_in_the_library() -> void:
	_fill("Swamp", 8)
	deck.add_side("Grizzly Bears")
	deck.add_side("Grizzly Bears")
	var sample := SampleHand.new(deck)
	assert_eq(sample.deck_size(), 8, "the main pile only")
	sample.new_hand()
	assert_false(sample.hand.has("Grizzly Bears"), "no sideboard card in hand")
	assert_false(sample.library.has("Grizzly Bears"), "nor in the library")


func test_a_seed_deals_the_same_hand_twice() -> void:
	_fill("Swamp", 12)
	_fill("Grizzly Bears", 12)
	_fill("Sengir Vampire", 12)
	_fill("Plains", 12)
	var first := SampleHand.new(deck, 4242)
	first.new_hand()
	var second := SampleHand.new(deck, 4242)
	second.new_hand()
	assert_eq(first.hand, second.hand, "the same seed, the same seven")
	assert_eq(first.library, second.library, "and the same library under it")


func test_a_deck_smaller_than_seven_deals_what_it_has() -> void:
	_fill("Swamp", 3)
	var sample := SampleHand.new(deck)
	sample.new_hand()
	assert_eq(sample.hand.size(), 3)
	assert_eq(sample.library_size(), 0)


func test_an_empty_deck_deals_nothing_and_refuses_nothing_loudly() -> void:
	var sample := SampleHand.new(deck)
	sample.new_hand()
	assert_eq(sample.hand.size(), 0)
	assert_false(sample.may_mulligan(), "nothing to throw back")
	assert_false(sample.mulligan(), "so the mulligan is refused")
	assert_eq(sample.next_hand_size(), 0)
	assert_false(sample.is_mulligan_hand(), "an empty hand is neither kind")
	assert_eq(sample.next_turn(), "", "and a turn draws nothing")
	assert_eq(sample.turn, 2, "but is still a turn")


# --------------------------------------------------------- the mulligan --

func test_the_mulligan_is_one_card_fewer_each_time_down_to_nothing() -> void:
	_fill("Swamp", 20)
	_fill("Grizzly Bears", 20)
	var sample := SampleHand.new(deck)
	sample.new_hand()
	for expected in [6, 5, 4, 3, 2, 1, 0]:
		assert_true(sample.may_mulligan(), "a hand of %d may be thrown back"
			% sample.hand.size())
		assert_eq(sample.next_hand_size(), expected, "the button says %d" % expected)
		assert_true(sample.mulligan(), "and it is taken")
		assert_eq(sample.hand.size(), expected, "one card fewer")
		assert_eq(sample.hand.size() + sample.library_size(), 40,
			"the whole hand went back before the redraw")
		assert_eq(sample.turn, 1, "a mulligan is still the opening")
	assert_eq(sample.mulligans, 7)
	assert_false(sample.may_mulligan(),
		"the seventh drew nothing, and nothing cannot be shuffled away again")
	assert_false(sample.mulligan(), "refused")
	assert_eq(sample.mulligans, 7, "and not counted")
	assert_eq(sample.next_hand_size(), 0)


func test_a_mulligan_from_a_small_deck_never_promises_more_than_it_has() -> void:
	_fill("Swamp", 3)
	var sample := SampleHand.new(deck)
	sample.new_hand()
	assert_eq(sample.next_hand_size(), 3, "6 would be a lie from three cards")
	sample.mulligan()
	assert_eq(sample.hand.size(), 3)
	for i in 4:
		sample.mulligan()   # 5, 4, 3, 2 -> the hand shrinks only past 3
	assert_eq(sample.mulligans, 5)
	assert_eq(sample.hand.size(), 2)


func test_a_new_hand_starts_over() -> void:
	_fill("Swamp", 20)
	_fill("Grizzly Bears", 20)
	var sample := SampleHand.new(deck)
	sample.new_hand()
	sample.mulligan()
	sample.mulligan()
	sample.next_turn()
	sample.next_turn()
	assert_eq(sample.hand.size(), 7, "five, plus two draws")
	assert_eq(sample.turn, 3)
	sample.new_hand()
	assert_eq(sample.hand.size(), 7)
	assert_eq(sample.mulligans, 0)
	assert_eq(sample.turn, 1)
	assert_eq(sample.library_size(), 33)


# ------------------------------------------------------------ the turns --

func test_next_turn_draws_one_off_the_top_and_stops_at_an_empty_library() -> void:
	_fill("Swamp", 8)
	var sample := SampleHand.new(deck)
	sample.new_hand()
	assert_eq(sample.library_size(), 1)
	assert_eq(sample.next_turn(), "Swamp", "the one card left")
	assert_eq(sample.turn, 2)
	assert_eq(sample.hand.size(), 8)
	assert_eq(sample.library_size(), 0)
	assert_eq(sample.next_turn(), "", "nothing to draw")
	assert_eq(sample.turn, 3, "the turn still passes")
	assert_eq(sample.hand.size(), 8, "and the hand is what it was")


func test_the_draw_is_the_top_of_the_library_in_order() -> void:
	_fill("Swamp", 12)
	_fill("Grizzly Bears", 12)
	var sample := SampleHand.new(deck, 7)
	sample.new_hand()
	var top: String = sample.library[sample.library.size() - 1]
	var under: String = sample.library[sample.library.size() - 2]
	assert_eq(sample.next_turn(), top, "the last entry is the top")
	assert_eq(sample.next_turn(), under, "then the one under it")
	assert_eq(sample.hand[7], top, "drawn cards go on the end of the hand")
	assert_eq(sample.hand[8], under)


# ------------------------------------------------------------- the lands --

func test_lands_are_counted_by_the_registry() -> void:
	assert_true(SampleHand.is_land_name("Swamp"))
	assert_true(SampleHand.is_land_name("Strip Mine"), "a nonbasic land too")
	assert_false(SampleHand.is_land_name("Grizzly Bears"))
	assert_false(SampleHand.is_land_name("Not A Card At All"),
		"a name the registry does not have is not a land")


func test_no_land_and_all_land_are_the_1997_rule_s_hands() -> void:
	_fill("Swamp", 10)
	var lands := SampleHand.new(deck)
	lands.new_hand()
	assert_eq(lands.lands_in_hand(), 7)
	assert_true(lands.is_mulligan_hand(), "nothing but land")
	deck = DeckModel.new()
	_fill("Grizzly Bears", 10)
	var spells := SampleHand.new(deck)
	spells.new_hand()
	assert_eq(spells.lands_in_hand(), 0)
	assert_true(spells.is_mulligan_hand(), "no land at all")
	deck = DeckModel.new()
	_fill("Swamp", 3)
	_fill("Grizzly Bears", 3)
	var mixed := SampleHand.new(deck)
	mixed.new_hand()
	assert_eq(mixed.lands_in_hand(), 3)
	assert_false(mixed.is_mulligan_hand(), "three of six is a hand to keep")


func test_a_proxy_is_in_the_deal_and_is_not_a_land() -> void:
	deck.add_proxy("Not A Card At All")
	deck.add_proxy("Not A Card At All")
	_fill("Swamp", 5)
	var sample := SampleHand.new(deck)
	assert_eq(sample.deck_size(), 7, "the proxies are cards of the deck")
	sample.new_hand()
	assert_eq(sample.hand.count("Not A Card At All"), 2, "and are dealt by name")
	assert_eq(sample.lands_in_hand(), 5, "the sample cannot know what they stand for")
	assert_false(sample.is_mulligan_hand())


# ------------------------------------------------- many hands, counted --

func test_a_thousand_hands_are_counted() -> void:
	_fill("Mountain", 16)
	_fill("Forest", 8)
	_fill("Lightning Bolt", 4)
	_fill("Grizzly Bears", 4)
	_fill("Hill Giant", 4)
	_fill("Craw Wurm", 4)
	var t := SampleHand.trials(deck, 1000, 7)
	assert_eq([t["runs"], t["hand"]], [1000, 7])
	var lands: Array = t["lands"]
	assert_eq(lands.size(), 8)
	var total := 0
	var weighted := 0
	for k in lands.size():
		total += int(lands[k])
		weighted += k * int(lands[k])
	assert_eq(total, 1000, "every hand is in one row")
	assert_almost_eq(float(t["average_lands"]), weighted / 1000.0, 0.0001)
	assert_almost_eq(float(t["average_lands"]), 7.0 * 24 / 40, 0.15, "near what the deck says")
	assert_eq(int(t["no_land"]), int(lands[0]))
	assert_eq(int(t["all_land"]), int(lands[7]))
	assert_eq(int(t["keepable"]), int(lands[2]) + int(lands[3]) + int(lands[4]) + int(lands[5]))
	# Which lands: both, the Mountain in more hands.
	var names: Array = t["land_names"]
	assert_eq([names[0]["name"], names[1]["name"]], ["Mountain", "Forest"])
	assert_true(int(names[0]["hands"]) > int(names[1]["hands"]) and int(names[0]["hands"]) <= 1000)
	assert_true(int(names[0]["copies"]) >= int(names[0]["hands"]))
	# The colors the spells ask for are red and green, and no other.
	var colors: Array = t["colors"]
	assert_eq(colors.map(func(row: Dictionary) -> int: return int(row["color"])), [Mtg.ManaColor.R, Mtg.ManaColor.G])
	assert_eq(int(colors[0]["hands"]), int(names[0]["hands"]), "a red source is a Mountain here")
	assert_true(int(t["every_color"]) <= int(colors[1]["hands"]))
	# Something to play: each a narrower hand than the next.
	assert_true(int(t["turn_one"]) <= int(t["turn_two"]) and int(t["turn_two"]) <= int(t["castable"]))
	assert_true(int(t["castable"]) <= 1000 - int(lands[0]))
	assert_true(int(t["creature"]) > 500)
	assert_true(float(t["average_cost"]) > 1.0 and float(t["average_cost"]) < 6.0)
	assert_eq((t["seen"] as Array).size(), 4, "the four spells, no land among them")
	# The same seed, the same count; nothing of the deck moved.
	assert_eq(SampleHand.trials(deck, 1000, 7), t)
	assert_eq(deck.total(), 40)


func test_the_edges_of_the_count() -> void:
	assert_eq(SampleHand.trials(deck, 1000, 1), {}, "an empty deck")
	_fill("Mountain", 3)
	var small := SampleHand.trials(deck, 50, 1)
	assert_eq([small["hand"], small["lands"], small["all_land"]], [3, [0, 0, 0, 50], 50])
	assert_eq(small["colors"], [], "no spell asks for a color")
	assert_eq([small["castable"], small["creature"], small["average_cost"]], [0, 0, 0.0])
