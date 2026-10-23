extends GutTest
## WHAT THE PLACES PAY FOR A CARD ([method CardShop.sell_range],
## [method CardShop.best_known_sale]) — the adventure deck builder's worth
## strip (the owner, 2026-10-23: the empty sideboard strip used "to display
## card under the mouse value for selling").

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


## The places of [param kind] in the world, in slot order.
func _places(kind: int) -> Array[int]:
	var out: Array[int] = []
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) == kind:
			out.append(slot)
	return out


func test_the_range_is_the_least_and_the_most_any_place_pays() -> void:
	var data := CardRegistry.get_card("Hill Giant")
	var least := 1 << 30
	var most := 0
	for code in ShandalarWorld.LANDS_MADE:
		var land := ShandalarWorld.magic_mask(code)
		for site_type in [ShandalarWorld.VILLAGE, ShandalarWorld.TOWN, ShandalarWorld.CITY]:
			least = mini(least, CardValue.sell_price(data, site_type, land))
			most = maxi(most, CardValue.sell_price(data, site_type, land))
	var paid := CardShop.sell_range("Hill Giant")
	assert_eq(paid, Vector2i(least, most))
	assert_true(paid.x > 0 and paid.x <= paid.y)
	# Every place in this world pays within it.
	for kind in [ShandalarWorld.VILLAGE, ShandalarWorld.TOWN, ShandalarWorld.CITY]:
		for slot in _places(kind):
			var price := CardShop.sell_price_at(player, slot, "Hill Giant")
			assert_between(price, paid.x, paid.y, "slot %d pays within the range" % slot)
	assert_eq(CardShop.sell_range("No Such Card Anywhere"), Vector2i.ZERO)


func test_the_best_known_is_among_the_places_visited_and_free() -> void:
	assert_true(CardShop.best_known_sale(player, "Hill Giant").is_empty(), "no place visited: none known")
	var village := _places(ShandalarWorld.VILLAGE)[0]
	var city := _places(ShandalarWorld.CITY)[0]
	TownStatus.put(player.world, village, TownStatus.VISITED)
	var best := CardShop.best_known_sale(player, "Hill Giant")
	assert_eq(int(best["slot"]), village, "the one place known")
	assert_eq(int(best["price"]), CardShop.sell_price_at(player, village, "Hill Giant"))
	assert_eq(String(best["name"]), WorldNames.site_name(player.world, village))
	TownStatus.put(player.world, city, TownStatus.VISITED)
	best = CardShop.best_known_sale(player, "Hill Giant")
	var city_pays := CardShop.sell_price_at(player, city, "Hill Giant")
	var village_pays := CardShop.sell_price_at(player, village, "Hill Giant")
	assert_eq(int(best["price"]), maxi(city_pays, village_pays), "the better of the two")
	TownStatus.take(player.world, city, 1)
	best = CardShop.best_known_sale(player, "Hill Giant")
	assert_eq(int(best["slot"]), village, "a city a wizard rules buys nothing")
	assert_true(CardShop.best_known_sale(player, "No Such Card Anywhere").is_empty())


## The bug pass after the campaign (r4-2): the lands are the ones the world
## is made of — a two-colour land no world has priced a dual land at a
## match no place pays.
func test_the_lands_are_the_ones_the_generator_makes() -> void:
	var made := {}
	for height in 256:
		for last in [0, 1, 5]:
			var code := WorldGenerator.terrain_for(height, last)
			if code != ShandalarWorld.OCEAN:
				made[code] = true
	var lands: Array = made.keys()
	lands.sort()
	assert_eq(lands, Array(ShandalarWorld.LANDS_MADE), "LANDS_MADE is what terrain_for makes")
	# A dual land: the low end is what a place on a land of its colours pays.
	var paid := CardShop.sell_range("Badlands")
	var least := 1 << 30
	for code in ShandalarWorld.LANDS_MADE:
		for site_type in [ShandalarWorld.VILLAGE, ShandalarWorld.TOWN, ShandalarWorld.CITY]:
			least = mini(least, CardValue.sell_price(CardRegistry.get_card("Badlands"), site_type,
				ShandalarWorld.magic_mask(code)))
	assert_eq(paid.x, least)
