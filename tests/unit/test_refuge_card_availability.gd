extends GutTest
## Pack 2 stock before travel, on the island and after liberation.

var pack_was_enabled := false

func before_each() -> void:
	pack_was_enabled = CardPacks.is_enabled(FallenEmpiresPack.ID)
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)

func after_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, pack_was_enabled)

func hero() -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	var record := setup.resolve({})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))

func names(rows: Array) -> Array:
	return rows.map(func(row: Dictionary) -> String: return row["name"])

func qualify(player: AdventurePlayer) -> void:
	for index in 5: RefugeCampaign.finish_quest(player, index)
	player.cards.clear()
	for i in 20:
		player.cards.append({"card": "Thallid", "decks": [0]})
		player.cards.append({"card": "Forest", "decks": [0]})

func assert_pools(player: AdventurePlayer, allowed: bool) -> void:
	var pools := [names(CardShop._draw_rules(player, 1)["stock"]), names(LairEvent.reward_pool(player))]
	for all_cards in [false, true]:
		player.all_trader_cards = all_cards
		for way in [CardTrade.TOWN, CardTrade.BAZAAR, CardTrade.MINE, CardTrade.REWARD]:
			pools.append(names(CardTrade.for_trader(player, way)))
	for pool in pools:
		assert_eq(pool.size(), pool.duplicate().reduce(func(held: Dictionary, card: String) -> Dictionary:
			held[card] = true
			return held, {}).size(), "no duplicate stock entries")
		for card in FallenEmpiresPack.names():
			assert_eq(pool.has(card), allowed, card)

func test_all_102_cards_follow_four_region_and_victory_states() -> void:
	var player := hero()
	assert_eq(FallenEmpiresPack.names().size(), 102)
	assert_pools(player, false)
	assert_true(RefugeCampaign.travel(player))
	assert_pools(player, true)
	qualify(player)
	assert_true(RefugeCampaign.liberate(player))
	assert_pools(player, true)
	assert_true(RefugeCampaign.travel(player))
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(player)
	if player == null: return
	assert_pools(player, true)
	assert_pools(hero(), false)

func test_owned_cards_can_return_before_liberation_without_unlocking_stock() -> void:
	var player := hero()
	assert_true(RefugeCampaign.travel(player))
	assert_true(RefugeCampaign.finish_quest(player, 0))
	assert_true(RefugeQuests.choose_reward(player, 0))
	var bag := player.cards.duplicate(true)
	assert_true(bag.any(func(row: Dictionary) -> bool: return row["card"] in FallenEmpiresPack.names()))
	assert_true(RefugeCampaign.travel(player))
	assert_eq(player.cards, bag)
	assert_false(RefugeCampaign.offers_cards(player))
	assert_gt(CardShop.sell_price_at(player, 1, "Thallid"), 0)
	assert_pools(player, false)
	player.amulets["green"] = WiseMan.COPY_COST
	var earned: String = bag.filter(func(row: Dictionary) -> bool: return row["card"] in FallenEmpiresPack.names())[0]["card"]
	assert_true(WiseMan.copy(player, earned, 3), "owned island spells may be copied at home")

func test_starter_and_mainland_core_catalogues_are_not_polluted() -> void:
	var player := hero()
	assert_true(RefugeCampaign.travel(player))
	assert_pools(player, true)
	for pool in [StarterDeck.cards(), CardShop.stock(), CardTrade.catalogue(), CardTrade.catalogue(true)]:
		for card in names(pool): assert_false(card in FallenEmpiresPack.names(), card)
	for row in ShandalarWorld.DUNGEON_CARDS:
		assert_false(String(row[1]) in FallenEmpiresPack.names())

func test_actual_shop_and_duel_reward_draws_follow_region() -> void:
	var player := hero()
	# The original spoil rules halve non-base copy limits; under forty
	# cards, that rounds down to zero. Use a normal forty-card deck.
	player.cards.clear()
	for i in 40: player.cards.append({"card": "Forest", "decks": [0]})
	for allowed in [false, true]:
		if allowed: assert_true(RefugeCampaign.travel(player))
		var found_shop := false
		var found_reward := false
		for seed_value in range(1, 65):
			var rules := CardShop._draw_rules(player, 1)
			# Every color, full rare slot: test drawing from the regional pool.
			rules["sold"] = CardShop.COLOR_BITS.duplicate()
			var card := CardShop._draw(2, false, MsvcRandom.new(seed_value * 7919), rules)
			found_shop = found_shop or card in FallenEmpiresPack.names()
			var rewards := DuelSpoils.reward_cards(player, {"color": 1 + seed_value % 5,
				"row": 1, "strength": 25}, MsvcRandom.new(seed_value * 7919))
			for reward in rewards: found_reward = found_reward or reward in FallenEmpiresPack.names()
		assert_eq(found_shop, allowed)
		assert_eq(found_reward, allowed)

func test_liberation_preserves_cached_shop_stock_until_restock() -> void:
	var player := hero()
	var stock := CardShop.offers(player, 1).duplicate()
	assert_true(RefugeCampaign.travel(player))
	qualify(player)
	assert_true(RefugeCampaign.liberate(player))
	assert_true(RefugeCampaign.travel(player))
	assert_eq(CardShop.offers(player, 1), stock)
	assert_has(names(CardShop._draw_rules(player, 1)["stock"]), "Thallid")

func test_disabling_pack_preserves_but_cannot_buy_unavailable_saved_stock() -> void:
	var player := hero()
	assert_true(RefugeCampaign.travel(player))
	CardShop.offers(player, 1)
	var shop := CardShop.town_record(player, 1)
	shop["cards"][0] = "Thallid"
	player.gold = 10000
	var bag := player.cards.duplicate(true)
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_false(CardRegistry.has_card("Thallid"))
	var answer := CardShop.buy(player, 1, 0)
	assert_false(answer["bought"])
	assert_eq(player.gold, 10000)
	assert_eq(player.cards, bag)
	assert_eq(shop["cards"][0], "Thallid")
	assert_false(RefugeCampaign.offers_cards(player))
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	assert_eq(CardShop.offers(player, 1)[0], "Thallid")
	assert_true(CardShop.buy(player, 1, 0)["bought"])
	assert_eq(player.cards.size(), bag.size() + 1)

func test_choice_and_artifact_gifts_respect_the_regional_gate() -> void:
	var player := hero()
	for allowed in [false, true]:
		if allowed: assert_true(RefugeCampaign.travel(player))
		var choice := {"pick_any": true}
		assert_eq(DuelSpoils.pick_any(player, choice, "Thallid"), allowed)
		assert_eq(choice["pick_any"], not allowed, "a refused choice is not spent")
		var found := false
		for seed_value in range(1, 160):
			var card := DuelSpoils._random_artifact(MsvcRandom.new(seed_value * 7919), player)
			found = found or card in FallenEmpiresPack.names()
		assert_eq(found, allowed)

func test_mainland_wizard_rewards_and_filters_gain_the_unlocked_cards() -> void:
	var player := hero()
	assert_false(CastleWin.offered(player, [], 3).has("Thallid"))
	assert_true(RefugeCampaign.travel(player))
	qualify(player)
	assert_true(RefugeCampaign.liberate(player))
	assert_true(RefugeCampaign.travel(player))
	# Avoid the Classic copy limit while testing the unlocked choice.
	player.cards.clear()
	assert_has(CastleWin.offered(player, [], 3), "Thallid")
	var pane := CastleWinPane.new()
	pane.player = player
	pane.record = {"color": 3}
	pane.type_filter = CardValue.CREATURE
	assert_has(pane.cards(), "Thallid")
	assert_false(pane.cards().has("Night Soil"))
	pane.type_filter = CardValue.ENCHANTMENT
	assert_has(pane.cards(), "Night Soil")
	assert_false(pane.cards().has("Thallid"))
	pane.free()
