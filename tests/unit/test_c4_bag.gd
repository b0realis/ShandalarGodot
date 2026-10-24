extends GutTest
## EVERY CARD THROUGH THE BAG (the bug pass of part B, q4-3). 1997 added
## every card the hero got through one adder (`AddCardToDeckSorted`): the
## 500-card bag, and "Acquired spell" in the journal for a rare. The shop,
## the lairs, the trades and the wise man's copy went round it; now they go
## through [method AdventurePlayer.add_card], and where the hero pays, a
## full bag refuses before the payment [ours: 1997 took the gold and lost
## the card].

var player: AdventurePlayer


func before_each() -> void:
	CardRegistry.ensure_loaded()
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))


func after_each() -> void:
	CardValue.forget()
	CardShop.forget()


func _town() -> int:
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			return slot
	return -1


func _fill_bag() -> void:
	while player.cards.size() < AdventurePlayer.BAG_MOST:
		player.cards.append({"card": "Mountain", "decks": []})


func _offered(slot: int) -> int:
	var cards := CardShop.offers(player, slot)
	for i in cards.size():
		if cards[i] != "":
			return i
	return -1


func test_the_shop_refuses_a_buy_to_a_full_bag_before_it_is_paid() -> void:
	var town := _town()
	var index := _offered(town)
	assert_gte(index, 0, "control: a card for sale")
	player.gold = 5000
	_fill_bag()
	var bought := CardShop.buy(player, town, index)
	assert_false(bool(bought["bought"]))
	assert_eq(String(bought["said"]), AdventurePlayer.BAG_FULL)
	assert_eq(player.gold, 5000, "no gold taken")
	assert_eq(player.cards.size(), AdventurePlayer.BAG_MOST)


func test_a_rare_bought_is_written_in_the_journal() -> void:
	var town := _town()
	player.gold = 5000
	var cards := CardShop.offers(player, town)
	var rare := -1
	for i in cards.size():
		if cards[i] != "" and AdventurePlayer._rarity(cards[i]) >= 3:
			rare = i
	if rare < 0:
		pass_test("no rare on offer in this world's first town")
		return
	CardShop.buy(player, town, rare)
	assert_eq(String(player.journal.back()["text"]), "Acquired spell: %s" % cards[rare])


func test_a_lair_s_card_is_lost_to_a_full_bag() -> void:
	_fill_bag()
	var event := {"reward": "Shivan Dragon"}
	assert_eq(LairEvent.finish(player, event), "", "nothing given")
	assert_eq(player.cards.size(), AdventurePlayer.BAG_MOST)


func test_a_trade_and_the_wise_man_s_copy_are_refused_to_a_full_bag() -> void:
	_fill_bag()
	player.gold = 5000
	var asked := CardTrade.offer(player, "Shivan Dragon", CardTrade.BAZAAR)
	var paid := CardTrade.pay(player, asked, CardTrade.BAZAAR)
	assert_false(bool(paid["traded"]))
	assert_eq(String(paid["said"]), AdventurePlayer.BAG_FULL)
	assert_eq(player.gold, 5000, "no gold taken")
	player.amulets["red"] = 3
	assert_false(WiseMan.copy(player, "Mountain", 4), "no copy")
	assert_eq(int(player.amulets["red"]), 3, "no amulet taken")
	assert_eq(player.cards.size(), AdventurePlayer.BAG_MOST)
