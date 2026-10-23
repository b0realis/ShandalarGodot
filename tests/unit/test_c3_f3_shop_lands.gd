extends GutTest
## Needs the imported 1997 skin: `adventure_cards.json`, the program's own
## card table. THE LANDS A 1997 SHOP SOLD (adventure campaign 2026-10-23,
## finding h1-7): its draw (`RunTownServicesMenu`, visitLocation.c
## 1810–1852) let a card through on its colour, the place's artifact rule
## and rarity, `expansion` & 0xC1, `extra_ability` 0x900 and 0x180 and the
## copies — never on its type, so two lands other than basic ones were sold,
## Mishra's Factory and Strip Mine, in the rare places; the Oasis passes the
## flags but has no colour at all, which no town sells.

var player: AdventurePlayer


func before_each() -> void:
	CardRegistry.ensure_loaded()
	CardValue.forget()
	CardShop.forget()
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


func test_the_1997_table_puts_two_lands_in_the_shops() -> void:
	assert_false(CardValue.original("Mishra's Factory").is_empty(), "the imported table is here")
	var names: Array[String] = []
	for row in CardShop.stock():
		names.append(String(row["name"]))
	assert_true("Mishra's Factory" in names)
	assert_true("Strip Mine" in names)
	for land in CardShop.LANDS:
		assert_false(land in names, land + ": by its own place only")
	for card_name in ["Library of Alexandria", "Badlands", "City of Brass", "Bazaar of Baghdad"]:
		assert_false(card_name in names, card_name + ": the flags keep it out")


func test_a_rare_place_may_draw_them_and_never_a_card_of_no_colour() -> void:
	var city := -1
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) == ShandalarWorld.CITY:
			city = slot
			break
	var rules := CardShop._draw_rules(player, city)
	var dice := MsvcRandom.new(7)
	var seen := {}
	for i in 3000:
		var card_name := CardShop._draw(2, false, dice, rules)
		seen[card_name] = true
		assert_false(card_name in CardShop.LANDS, "no basic land outside the land's place")
	assert_true(seen.has("Mishra's Factory") or seen.has("Strip Mine"), "a land of the program's in a rare place")
	assert_false(seen.has("Oasis"), "no colour at all: never sold")
	var common := MsvcRandom.new(7)
	for i in 500:
		assert_false(CardShop._draw(0, false, common, rules) in ["Mishra's Factory", "Strip Mine"],
			"rare: never in a common place")
