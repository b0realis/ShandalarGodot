extends GutTest
## Pack 2 stock in a campaign with the Last Refuge plugin ticked: on the
## mainland, on the island and after the finale. ADVENTURE PLUGINS
## (2026-11-10, §0.2 of the plugin spec): a card pack behaves as in the
## vanilla adventure — the plugin names the pack it needs and never
## withholds or unlocks its cards. (Before, Fallen Empires cards reached the
## mainland only once the island was liberated; these tests pinned that and
## are rewritten for the ruling: the same pools everywhere, and still none
## of the pack's cards in a campaign without it or with it switched off.)

var pack_was_enabled := false


func before_each() -> void:
	pack_was_enabled = CardPacks.is_enabled(FallenEmpiresPack.ID)
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)

func after_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, pack_was_enabled)

func hero(with_pack := true) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	if with_pack:
		setup.adventures = ["refuge"]
		setup.packs = ["pack-2"]
	setup.seed_text = "48271"
	var record := setup.resolve({"pack-2": "1"} if with_pack else {})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))

func names(rows: Array) -> Array:
	return rows.map(func(row: Dictionary) -> String: return row["name"])

func qualify(player: AdventurePlayer) -> void:
	for index in 5: _refuge().finish_quest(player, index)
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

func test_all_102_cards_are_offered_in_every_region_and_state() -> void:
	var player := hero()
	assert_eq(FallenEmpiresPack.names().size(), 102)
	assert_pools(player, true)
	assert_true(_refuge().travel(player))
	assert_pools(player, true)
	qualify(player)
	assert_true(_refuge().win_finale(player))
	assert_pools(player, true)
	assert_true(_refuge().travel(player))
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(player)
	if player == null: return
	assert_pools(player, true)
	assert_pools(hero(false), false)

func test_the_plugin_never_gates_its_pack() -> void:
	var player := hero()
	assert_true(AdventurePacks.offers_cards(player, FallenEmpiresPack.ID), "the mainland, before any voyage")
	assert_true(_refuge().travel(player))
	assert_true(AdventurePacks.offers_cards(player, FallenEmpiresPack.ID), "the island")
	assert_true(_refuge().travel(player))
	assert_true(AdventurePacks.offers_cards(player, FallenEmpiresPack.ID), "home again, the island not freed")
	assert_false(AdventurePacks.offers_cards(hero(false), FallenEmpiresPack.ID), "a campaign without the pack")
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_false(AdventurePacks.offers_cards(player, FallenEmpiresPack.ID), "the pack switched off")

func test_owned_island_cards_go_home_and_can_be_copied() -> void:
	var player := hero()
	assert_true(_refuge().travel(player))
	assert_true(_refuge().finish_quest(player, 0))
	assert_true(_refuge().choose_reward(player, 0))
	var bag := player.cards.duplicate(true)
	assert_true(bag.any(func(row: Dictionary) -> bool: return row["card"] in FallenEmpiresPack.names()))
	assert_true(_refuge().travel(player))
	assert_eq(player.cards, bag)
	assert_gt(CardShop.sell_price_at(player, 1, "Thallid"), 0)
	assert_pools(player, true)
	player.amulets["green"] = WiseMan.COPY_COST
	var earned: String = bag.filter(func(row: Dictionary) -> bool: return row["card"] in FallenEmpiresPack.names())[0]["card"]
	assert_true(WiseMan.copy(player, earned, 3), "owned island spells may be copied at home")

func test_starter_and_mainland_core_catalogues_are_not_polluted() -> void:
	var player := hero()
	assert_true(_refuge().travel(player))
	assert_pools(player, true)
	for pool in [StarterDeck.cards(), CardShop.stock(), CardTrade.catalogue(), CardTrade.catalogue(true)]:
		for card in names(pool): assert_false(card in FallenEmpiresPack.names(), card)
	for row in ShandalarWorld.DUNGEON_CARDS:
		assert_false(String(row[1]) in FallenEmpiresPack.names())

func test_actual_shop_and_duel_reward_draws_include_the_pack_in_both_regions() -> void:
	for with_pack in [true, false]:
		var player := hero(with_pack)
		# The original spoil rules halve non-base copy limits; under forty
		# cards, that rounds down to zero. Use a normal forty-card deck.
		player.cards.clear()
		for i in 40: player.cards.append({"card": "Forest", "decks": [0]})
		for island in ([false, true] if with_pack else [false]):
			if island: assert_true(_refuge().travel(player))
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
			assert_eq(found_shop, with_pack, "shop (island=%s, pack=%s)" % [island, with_pack])
			assert_eq(found_reward, with_pack, "spoils (island=%s, pack=%s)" % [island, with_pack])

func test_the_finale_preserves_cached_shop_stock_until_restock() -> void:
	var player := hero()
	var stock := CardShop.offers(player, 1).duplicate()
	assert_true(_refuge().travel(player))
	qualify(player)
	assert_true(_refuge().win_finale(player))
	assert_true(_refuge().travel(player))
	assert_eq(CardShop.offers(player, 1), stock)
	assert_has(names(CardShop._draw_rules(player, 1)["stock"]), "Thallid")

func test_disabling_pack_preserves_but_cannot_buy_unavailable_saved_stock() -> void:
	var player := hero()
	assert_true(_refuge().travel(player))
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
	assert_false(AdventurePacks.offers_cards(player, FallenEmpiresPack.ID))
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	assert_eq(CardShop.offers(player, 1)[0], "Thallid")
	assert_true(CardShop.buy(player, 1, 0)["bought"])
	assert_eq(player.cards.size(), bag.size() + 1)

func test_choice_and_artifact_gifts_offer_the_pack_in_both_regions() -> void:
	var player := hero()
	for island in [false, true]:
		if island: assert_true(_refuge().travel(player))
		var choice := {"pick_any": true}
		assert_true(DuelSpoils.pick_any(player, choice, "Thallid"), "island=%s" % island)
		assert_false(choice["pick_any"], "the choice is spent")
		var found := false
		for seed_value in range(1, 160):
			var card := DuelSpoils._random_artifact(MsvcRandom.new(seed_value * 7919), player)
			found = found or card in FallenEmpiresPack.names()
		assert_true(found, "island=%s" % island)
	var without := hero(false)
	var refused := {"pick_any": true}
	assert_false(DuelSpoils.pick_any(without, refused, "Thallid"), "a campaign without the pack")
	assert_true(refused["pick_any"], "a refused choice is not spent")

func test_mainland_wizard_rewards_and_filters_offer_the_pack_from_the_start() -> void:
	var player := hero()
	# Avoid the Classic copy limit while testing the choice.
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
	assert_false(CastleWin.offered(hero(false), [], 3).has("Thallid"), "never without the pack")


## The prototype plugin's interpreter ([DataRegion]).
func _refuge() -> DataRegion:
	return AdventureExpansions.provider("refuge") as DataRegion
