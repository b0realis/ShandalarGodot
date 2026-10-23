extends GutTest
## WHAT A CARD IS WORTH AND WHAT A TOWN SELLS (2026-10-23): [CardValue] is
## the 1997 game's `CalculateCardShopPrice`, its town and sale prices
## (`RunTownBuyCardsScreen`, `SellPrice`); [CardShop] the 1997 shop's
## offers (`RunTownServicesMenu`).


## The 1997 inputs of a card, as the importer reads them from the program.
func _facts(kind: int, color: int, cc0: int, cc1: int, power: int, tough: int, ai: int,
		rarity: int, vanilla := true, static_bits := 0, extra := 0) -> Dictionary:
	return {"type": kind, "color": color, "cc0": cc0, "cc1": cc1, "power": power, "tough": tough,
		"ai": ai, "rarity": rarity, "vanilla": vanilla, "static": static_bits, "extra": extra, "exp": 1}


func test_the_1997_formula_on_its_own_numbers() -> void:
	assert_eq(CardValue.price_of(_facts(CardValue.LAND, 2, 0, 0, 0, 0, 0, 1)), 40, "a Swamp")
	assert_eq(CardValue.price_of(_facts(CardValue.CREATURE, 8, 1, 1, 2, 2, 1, 1)), 50,
		"Grizzly Bears: (1 + 5) · 5 · 5 / 3")
	assert_eq(CardValue.price_of(_facts(CardValue.CREATURE, 32, 2, 3, 4, 4, 2, 2, false, 0x20, 0x200)), 312,
		"Serra Angel: 315, rules ×1.5, /6, uncommon ×2, a staple ×2 — flying adds nothing")
	assert_eq(CardValue.price_of(_facts(CardValue.INSTANT, 16, 1, 0, 0, 0, 3, 1, false, 0, 0x200)), 280,
		"Lightning Bolt: 60 + 80, a staple ×2")
	assert_eq(CardValue.price_of(_facts(CardValue.CREATURE, 16, 2, 4, 5, 5, 2, 3, false, 0x20, 0x9)), 1028,
		"Shivan Dragon: 400, ×1.5, firebreathing ×3, /7, rare ×4")
	assert_eq(CardValue.price_of(_facts(CardValue.ARTIFACT, 1, 0, 0, 0, 0, 3, 3, false, 0, 0x180)), 400,
		"Black Lotus: 250 / 5, power: special ×8")


func test_a_town_s_price_and_what_it_pays() -> void:
	CardRegistry.ensure_loaded()
	var bears := CardRegistry.get_card("Grizzly Bears")
	var base := CardValue.base_price(bears)
	assert_eq(CardValue.buy_price(bears, 1, 8), clampi(base * 3 / 50 * 5, 5, 1000), "a green village: base × 3, by fives")
	assert_eq(CardValue.buy_price(bears, 3, 8), clampi(base * 5 / 50 * 5, 5, 1000), "a green city: × 5")
	assert_eq(CardValue.buy_price(bears, 1, 2), clampi(base * 3 * 2 / 50 * 5, 5, 1000), "a black village: twice")
	assert_eq(CardValue.buy_price(bears, 1, 16), clampi(base * 3 * 3 / 2 / 50 * 5, 5, 1000),
		"a red village, whose colour goes with green: half again")
	assert_eq(CardValue.sell_price(bears, 1, 8), CardValue.buy_price(bears, 1, 8), "on its colour it sells for its price")


func test_a_card_the_1997_game_never_had_is_priced_from_its_stats() -> void:
	CardRegistry.ensure_loaded()
	var bears_card := CardRegistry.get_card("Grizzly Bears")
	var bears := CardValue.derive(bears_card)
	assert_true(bears["derived"])
	assert_eq([bears["type"], bears["color"], bears["cc0"], bears["cc1"], bears["power"], bears["tough"]],
		[CardValue.CREATURE, 8, 1, 1, 2, 2])
	assert_eq(bears["ai"], clampi(1 + CardValue.strength_step(bears_card, CardValue.CREATURE), -2, 3),
		"a creature's usual value, moved by what the engine reads in it")
	assert_true(bears["vanilla"], "no rules but its stats")
	var angel := CardValue.derive(CardRegistry.get_card("Serra Angel"))
	assert_false(angel["vanilla"], "vigilance is rules (the program's own code)")
	var shivan := CardValue.derive(CardRegistry.get_card("Shivan Dragon"))
	assert_ne(int(shivan["extra"]) & CardValue.PUMP_POWER, 0, "firebreathing read off its rules")
	var bolt := CardValue.derive(CardRegistry.get_card("Lightning Bolt"))
	assert_eq(bolt["ai"], 3, "its burn read as a strong instant: the 1997 game's own hand-tuned 3")
	assert_eq(CardValue.price_of(bolt), 3 * 20 + 2 * 40, "ai · 20 + (mana value + 1) · 40")
	var plain := CardValue.derive(CardRegistry.get_card("Giant Growth"))
	assert_gt(CardValue.price_of(bolt), CardValue.price_of(plain) - 1, "burn is worth at least a pump")


## A shop on a seeded world: the 1997 rules hold.
func test_a_town_offers_cards_by_the_1997_rules() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "green"
	setup.difficulty = 1
	setup.seed_text = "12345"
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	var towns := {}
	for slot in player.world.sites.size():
		var kind := int(player.world.sites[slot]["type"])
		if kind >= 1 and kind <= 3 and not towns.has(kind):
			towns[kind] = slot
	for kind in towns:
		var slot: int = towns[kind]
		var cards := CardShop.offers(player, slot)
		assert_eq(cards.size(), kind + 3, "village 4, town 5, city 6")
		var sold := CardShop.colors_sold(player.world, slot)
		var lands := 0
		for i in cards.size():
			var card_name := cards[i]
			assert_ne(card_name, "", "every place filled on the first visit")
			if card_name in CardShop.LANDS:
				lands += 1
				continue
			var f := CardValue.facts(CardRegistry.get_card(card_name))
			var bits := int(f["color"])
			assert_true(bits == CardValue.COLORLESS or CardValue.first_color(bits) in sold, card_name + ": the town's colours")
			assert_lte(CardShop.shop_rarity(f), i % 3 + 1, card_name + ": the place's rarity")
			if i % 2 == 1:
				assert_eq(int(f["type"]) & CardValue.ARTIFACT, 0, card_name + ": no artifact in an even place")
			assert_true(CardValue.is_base(card_name), card_name + ": the base set")
		assert_eq(lands >= 1, true, "a basic land among them")
		assert_eq(CardShop.offers(player, slot), cards, "and they stay")
	# Buying: the gold, the hero's cards, the place empty until the clock.
	var slot: int = towns[ShandalarWorld.TOWN]
	var cards := CardShop.offers(player, slot)
	var price := CardShop.price_at(player, slot, cards[0])
	var gold := player.gold
	player.gold = price - 1
	assert_false(CardShop.buy(player, slot, 0)["bought"], "not enough gold")
	player.gold = gold + price
	var owned := player.cards.size()
	var done := CardShop.buy(player, slot, 0)
	assert_true(done["bought"])
	assert_eq(player.gold, gold, "paid")
	assert_eq(player.cards.size(), owned + 1)
	assert_eq(player.cards[-1], {"card": cards[0], "decks": []}, "in no deck")
	assert_eq(CardShop.offers(player, slot)[0], "", "the place is empty")
	player.quest_timer += (player.difficulty + 3) * 5 + 4 * (player.difficulty + 2)
	assert_ne(CardShop.offers(player, slot)[0], "", "restocked in time")
	# Kept with the adventure.
	var again := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_eq(CardShop.offers(again, slot), CardShop.offers(player, slot), "saved and loaded")


func test_haggler_s_coin_adds_a_card() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "blue"
	setup.seed_text = "777"
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	var slot := -1
	for i in player.world.sites.size():
		if int(player.world.sites[i]["type"]) == ShandalarWorld.VILLAGE:
			slot = i
			break
	player.world_magics.append("Haggler's Coin")
	assert_eq(CardShop.offers(player, slot).size(), 5, "a village's four and one more")
