extends GutTest
## Original acquisition rules at the optional-pack boundary.
var previous: Array[String] = []

func before_each() -> void:
	previous = Settings.enabled_card_packs().duplicate()
	CardPacks.set_enabled("pack-1", true)
	CardPacks.set_enabled("pack-2", true)
	StarterDeck._cards.clear()

func after_each() -> void:
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != (id in previous): CardPacks.set_enabled(id, id in previous)
	StarterDeck._cards.clear()
	AdventureSetup.forget()

func hero(rule := AdventurePlayer.RULE_MEANT, size := 40) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	setup.card_rule = rule
	setup.packs = ["pack-2"]
	var record := setup.resolve({"pack-2": "1"})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	player.cards.clear()
	for i in size: player.cards.append({"card": "Forest", "decks": [0]})
	return player

func thallid_draw(player: AdventurePlayer) -> String:
	var rules := CardShop._draw_rules(player, 1)
	rules["sold"] = [8] as Array[int]
	rules["stock"] = [{"name": "Thallid", "facts": CardValue.facts(CardRegistry.get_card("Thallid"))}]
	# The pack's only card, no base card (0.60.14: a campaign with packs
	# draws by the pack share, from `base` and `packs`).
	rules["base"] = [] as Array[Dictionary]
	rules["packs"] = [rules["stock"]]
	return CardShop._draw(0, false, MsvcRandom.new(17), rules)

func test_first_deck_uses_the_original_base_flags_and_special_rarity() -> void:
	var pool := {}
	for row in StarterDeck.cards(): pool[row["name"]] = row
	for name in ["Icy Manipulator", "Basalt Monolith", "Shahrazad", "Thallid", "Serendib Efreet", "Black Lotus"]:
		assert_false(pool.has(name), name + " is not a starter candidate")
	for name in ["Giant Badger", "Goblin Polka Band", "Aswan Jaguar", "Ironclaw Orcs"]:
		assert_true(pool.has(name), name + " is an eligible base-set card")
	assert_eq(int(pool["Ironclaw Orcs"]["rarity"]), 4, "1997 marked this card special, despite its common printing")
	if pool.has("Goblin Polka Band"):
		assert_eq(int(pool["Goblin Polka Band"]["rarity"]), 4)

func test_artifact_creatures_can_fill_an_artifact_spell_slot() -> void:
	var full := StarterDeck.cards().duplicate(true)
	StarterDeck._cards.assign(full.filter(func(row: Dictionary) -> bool: return row["name"] == "Ornithopter"))
	var dealt: Array[String] = []
	# MSVC seed 1 starts with 41: the artifact side of the coin.
	StarterDeck._share(dealt, "green", 0, 1, 0, false, 0, MsvcRandom.new(1))
	StarterDeck._cards.assign(full)
	assert_eq(dealt, ["Ornithopter"] as Array[String])

func test_pack_shop_follows_the_chosen_copy_rule_without_a_new_size_gate() -> void:
	var player := hero(AdventurePlayer.RULE_MEANT, 36)
	assert_eq(thallid_draw(player), "Thallid", "a 36-card starter can find a pack card in a shop")
	player.cards[0]["card"] = "Thallid"
	assert_eq(thallid_draw(player), "", "as intended counts the one copy in use")
	player = hero(AdventurePlayer.RULE_MEANT, 40)
	assert_eq(thallid_draw(player), "Thallid")
	player.cards[0]["card"] = "Thallid"
	assert_eq(thallid_draw(player), "Thallid", "forty cards allow two shop copies")
	player.cards[1]["card"] = "Thallid"
	assert_eq(thallid_draw(player), "", "both copies in use")
	player.cards[0]["decks"] = []
	player.cards.append({"card": "Forest", "decks": [0]})
	assert_eq(thallid_draw(player), "Thallid", "a spare copy is not an in-deck copy")

func test_pack_shop_retains_each_campaign_copy_mode() -> void:
	var player := hero(AdventurePlayer.RULE_SHIPPED, 36)
	for i in 4: player.cards[i]["card"] = "Thallid"
	assert_eq(thallid_draw(player), "Thallid", "as shipped preserves the original counting bug")
	player.card_rule = AdventurePlayer.RULE_CLASSIC
	assert_eq(thallid_draw(player), "", "classic counts every owned copy")
	player.cards[0]["card"] = "Forest"
	assert_eq(thallid_draw(player), "Thallid")
	assert_eq(thallid_draw(hero(AdventurePlayer.RULE_CLASSIC, 36)), "Thallid", "classic does not halve non-base copies")

func test_original_reward_restrictions_do_not_block_shops_or_paid_trades() -> void:
	var player := hero(AdventurePlayer.RULE_MEANT, 36)
	var facts := CardValue.facts(CardRegistry.get_card("Thallid"))
	for rule in [AdventurePlayer.RULE_MEANT, AdventurePlayer.RULE_SHIPPED]:
		player.card_rule = rule
		assert_eq(CardShop.copies_left(player, "Thallid", facts,
			CardShop.counted_copies(player), CardShop.copies_allowed(player)), 0,
			"the original non-base reward allowance still rounds down")
		assert_eq(thallid_draw(player), "Thallid", "no new shop size restriction")
	assert_true(CardTrade.for_trader(player, CardTrade.TOWN).any(func(row: Dictionary) -> bool: return row["name"] == "Thallid"))
	assert_eq(CardTrade.amulets_for(CardValue.facts(CardRegistry.get_card("Thallid"))), 1)
	assert_true(CardShop.may_offer(player, "Thallid"), "the 1997 trade is allowed even when its label is dim")

func test_trade_confirmation_rechecks_region_pack_and_classic_limits() -> void:
	for cause in ["region", "disabled", "copies"]:
		var player := hero(AdventurePlayer.RULE_CLASSIC)
		player.amulets["green"] = 10
		var asked := CardTrade.offer(player, "Thallid", CardTrade.TOWN, "green")
		if cause == "region": player.expanded_adventure = true
		if cause == "disabled": CardPacks.set_enabled("pack-2", false)
		if cause == "copies":
			for i in 4: player.cards[i]["card"] = "Thallid"
		var before := player.cards.duplicate(true)
		var dice := player.dice
		assert_false(CardTrade.pay(player, asked, CardTrade.TOWN, "green")["traded"], cause)
		assert_eq(player.cards, before, cause + ": no card added")
		assert_eq(player.amulets["green"], 10, cause + ": no payment")
		assert_eq(player.dice, dice, cause + ": no dice spent")
		CardPacks.set_enabled("pack-2", true)

func test_free_trade_reward_cannot_bypass_unlock_or_treasure_rules() -> void:
	var player := hero()
	player.expanded_adventure = true
	player.all_trader_cards = true
	var before := player.cards.duplicate(true)
	for name in ["Thallid", "Black Lotus"]:
		var asked := CardTrade.offer(player, name, CardTrade.REWARD)
		assert_false(CardTrade.pay(player, asked, CardTrade.REWARD)["traded"], name)
		assert_eq(player.cards, before)

func test_card_and_skin_changes_invalidate_acquisition_caches() -> void:
	var before := StarterDeck.cards().duplicate(true)
	# A registry rebuild must discard an earlier deal's cached catalogue.
	StarterDeck._cards.resize(1)
	CardPacks.set_enabled("pack-1", false)
	assert_eq(StarterDeck.cards(), before, "enabling/disabling unrelated cards cannot change the starter pool")
	assert_false(AdventurePacks.card_stock("pack-2").is_empty())
	SkinPack._forget_adventure_tables()
	assert_true(StarterDeck._cards.is_empty())
	assert_true(AdventurePacks._stock.is_empty())
	assert_eq(StarterDeck.cards(), before)

func test_offer_and_builder_boundaries_are_distinct_with_and_without_tome() -> void:
	# size, normal shop allowance, normal FE reward allowance, builder cap,
	# Tome shop allowance, Tome FE reward allowance, Tome builder cap (0 = unlimited).
	for row in [[36, 1, 0, 3, 2, 1, 4], [39, 1, 0, 3, 2, 1, 4],
			[40, 2, 1, 3, 3, 1, 4], [58, 2, 1, 3, 3, 1, 4],
			[59, 2, 1, 4, 3, 1, 0], [60, 3, 1, 4, 4, 2, 0]]:
		var player := hero(AdventurePlayer.RULE_MEANT, row[0])
		var facts := CardValue.facts(CardRegistry.get_card("Thallid"))
		for tome in [false, true]:
			if tome: player.world_magics.append("Tome of Enlightenment")
			var offset := 4 if tome else 1
			assert_eq(CardShop.copies_allowed(player), row[offset], str(row[0]))
			assert_eq(CardShop.copies_left(player, "Thallid", facts,
				CardShop.counted_copies(player), CardShop.copies_allowed(player)), row[offset + 1], str(row[0]))
			assert_eq(DeckModel.copies_allowed_1997(row[0], tome), row[offset + 2], str(row[0]))
			assert_eq(thallid_draw(player), "Thallid", "every size can draw a first pack shop card")

func test_duel_land_padding_never_changes_the_acquisition_deck_size() -> void:
	for rule in AdventurePlayer.CARD_RULES:
		var player := hero(rule, 36)
		for difficulty in 4:
			player.difficulty = difficulty
			var padded := CreatureMeeting.padded_deck(player, player.deck_cards())
			assert_eq(padded.size(), [36, 36, 40, 40][difficulty], rule)
			assert_eq(player.deck_cards().size(), 36, "temporary lands are not owned cards")
			assert_eq(CardShop.copies_allowed(player), 1, "reward size uses the actual deck")
			assert_true(CardShop.may_offer(player, "Thallid"), rule)
