extends GutTest
## Same-town buy/resell regressions from the 0.60 playtest. The original
## sale formula used exact color equality where buying used overlap, and
## only purchases had a price ceiling. Travel between markets still pays.


func before_each() -> void:
	CardRegistry.ensure_loaded()
	CardValue.forget()


func after_each() -> void:
	CardValue.forget()


## Karma's imported 1997 valuation inputs. This regression needs no skin.
func _karma() -> CardData:
	CardValue._imported = {"Karma": {"type": 4, "color": 32, "cc0": 2, "cc1": 2,
		"power": 0, "tough": 0, "ai": 0, "rarity": 2, "vanilla": false,
		"static": 0, "extra": 1, "exp": 1}}
	CardValue._imported_read = true
	CardValue._read_at = CardRegistry.revision
	return CardRegistry.get_card("Karma")


func test_karma_cannot_be_bought_for_200_and_sold_for_300_in_the_same_town() -> void:
	var card := _karma()
	assert_eq(CardValue.base_price(card), 500, "the imported valuation")
	for terrain in [13, 10]: # Black/white and green/white land, both generated.
		var colors := ShandalarWorld.magic_mask(terrain)
		assert_eq(CardValue.buy_price(card, ShandalarWorld.TOWN, colors), 200)
		assert_eq(CardValue.sell_price(card, ShandalarWorld.TOWN, colors), 200,
			"sharing the town's white cannot earn a resale bonus")


func test_unaffected_prices_and_profitable_travel_between_towns_remain() -> void:
	var card := _karma()
	# Terrain, town's asking price, town's buying price.
	for row in [[6, 200, 200], [1, 300, 265], [3, 400, 300]]:
		var colors := ShandalarWorld.magic_mask(int(row[0]))
		assert_eq(CardValue.buy_price(card, ShandalarWorld.TOWN, colors), int(row[1]))
		assert_eq(CardValue.sell_price(card, ShandalarWorld.TOWN, colors), int(row[2]))
	var bought := CardValue.buy_price(card, ShandalarWorld.VILLAGE, 32)
	var sold_elsewhere := CardValue.sell_price(card, ShandalarWorld.CITY, 2)
	assert_eq(bought, 150)
	assert_eq(sold_elsewhere, 375)
	assert_gt(sold_elsewhere, bought, "travelling to another market can still earn gold")


func test_the_purchase_ceiling_cannot_create_a_resale_profit() -> void:
	var card := CardData.new("Resale ceiling probe", "{G}", Mtg.CardType.CREATURE)
	card.power = 40
	card.toughness = 40
	var bought := CardValue.buy_price(card, ShandalarWorld.CITY, 8)
	assert_eq(bought, 1000, "an expensive card reaches the existing purchase ceiling")
	assert_eq(CardValue.sell_price(card, ShandalarWorld.CITY, 8), bought)


func test_all_loaded_cards_cannot_make_gold_by_reselling_in_the_same_market() -> void:
	var bad: Array[String] = []
	var checked := 0
	for card_name in CardRegistry.all_names():
		var card := CardRegistry.get_card(String(card_name))
		for terrain in ShandalarWorld.LANDS_MADE:
			var colors := ShandalarWorld.magic_mask(terrain)
			for kind in [ShandalarWorld.VILLAGE, ShandalarWorld.TOWN, ShandalarWorld.CITY]:
				var bought := CardValue.buy_price(card, kind, colors)
				var sold := CardValue.sell_price(card, kind, colors)
				if sold > bought or sold < 0:
					bad.append("%s at %d/%d: buy %d, sell %d" % [card_name, kind, terrain, bought, sold])
				checked += 1
	assert_gt(checked, 20000, "the whole catalogue, every generated terrain and town size")
	assert_true(bad.is_empty(), "%d invalid prices: %s" % [bad.size(), "; ".join(bad.slice(0, 8))])
