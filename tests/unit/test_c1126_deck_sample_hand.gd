extends GutTest
## Campaign 2026-11-26, bugs2 #1: "1000 hands" counted a proxy as a spell
## that costs nothing (a turn-one play in nearly every hand, a very low
## average mana value, the proxy leading "the spells seen most"), and a
## hand of only free real spells as no play at all.

var deck: DeckModel


func before_each() -> void:
	CardRegistry.ensure_loaded()
	deck = DeckModel.new()


func _fill(card_name: String, n: int) -> void:
	for i in n:
		deck.add(card_name)


func test_a_proxy_is_no_play_no_cost_and_no_spell_seen() -> void:
	_fill("Swamp", 20)
	_fill("Sengir Vampire", 4)
	for i in 9:
		for copy in 4:
			deck.add_proxy("Zzz Proxy %d" % i)
	assert_eq(deck.total(), 60)
	var t := SampleHand.trials(deck, 1000, 7)
	assert_eq(int(t["turn_one"]), 0, "a five-mana spell is no turn-one play")
	assert_eq(int(t["turn_two"]), 0)
	assert_almost_eq(float(t["average_cost"]), 5.0, 0.001, "only the Vampire has a cost")
	for row: Dictionary in t["seen"]:
		assert_eq(String(row["name"]), "Sengir Vampire", "a proxy is not a spell seen")
	# The proxies still took their places in the seven.
	assert_true(float(t["average_lands"]) < 3.0, "20 lands in 60: %.2f" % float(t["average_lands"]))
	# The same deck without them reads the same plays.
	var bare := DeckModel.new()
	for i in 20:
		bare.add("Swamp")
	for i in 4:
		bare.add("Sengir Vampire")
	var b := SampleHand.trials(bare, 1000, 7)
	assert_eq(int(b["turn_one"]), 0)
	assert_almost_eq(float(b["average_cost"]), 5.0, 0.001)


func test_a_deck_of_proxies_alone_has_nothing_to_play() -> void:
	for i in 10:
		for copy in 4:
			deck.add_proxy("Zzz Proxy %d" % i)
	var t := SampleHand.trials(deck, 200, 3)
	assert_eq(int(t["turn_one"]), 0)
	assert_eq(int(t["castable"]), 0)
	assert_eq(int(t["creature"]), 0)
	assert_eq(float(t["average_cost"]), 0.0)
	assert_eq((t["seen"] as Array).size(), 0)
	assert_eq(int(t["no_land"]), 200)


func test_a_free_spell_is_a_play_with_no_land() -> void:
	_fill("Ornithopter", 4)
	_fill("Black Lotus", 3)
	var t := SampleHand.trials(deck, 100, 5)
	assert_eq(int(t["no_land"]), 100)
	assert_eq(int(t["turn_one"]), 100, "Ornithopter costs nothing")
	assert_eq(int(t["turn_two"]), 100)
	assert_eq(int(t["castable"]), 100)
	assert_eq(int(t["creature"]), 100)


func test_a_spell_with_a_cost_still_waits_for_its_lands() -> void:
	_fill("Mountain", 20)
	_fill("Lightning Bolt", 4)
	_fill("Hill Giant", 16)
	var t := SampleHand.trials(deck, 1000, 11)
	var lands: Array = t["lands"]
	assert_true(int(t["turn_one"]) <= 1000 - int(lands[0]), "no land, no Bolt")
	assert_true(int(t["turn_one"]) > 0)
	assert_true(int(t["turn_one"]) <= int(t["turn_two"]))
	assert_true(int(t["turn_two"]) <= int(t["castable"]))
	assert_true(int(t["castable"]) <= 1000 - int(lands[0]))
	# No land hands: nothing castable. Rebuild the count by hand with the same seed.
	var sample := SampleHand.new(deck, 11)
	var castable := 0
	for run in 1000:
		sample._deal(7)
		var n := sample.lands_in_hand()
		var cheapest := 99
		for card_name in sample.hand:
			if card_name == "Lightning Bolt":
				cheapest = mini(cheapest, 1)
			elif card_name == "Hill Giant":
				cheapest = mini(cheapest, 4)
		if cheapest <= n:
			castable += 1
	assert_eq(int(t["castable"]), castable)
