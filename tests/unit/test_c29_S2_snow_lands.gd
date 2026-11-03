extends GutTest
## ICE AGE'S SNOW-COVERED BASICS ARE BASIC LANDS IN THE ADVENTURE (0.60.15,
## the owner's ruling of 2026-11-03): with Pack 3 among the campaign's packs,
## like Plains … Forest — the land's place of a shop their only place (by the
## pack share there), no copy limit, four for one amulet at a trader —
## matching the deck rules (`DeckFormat.is_basic`: the Basic supertype).
## Without Pack 3 in the campaign nothing changes, the land's place's die
## included.

const SNOW: Array[String] = ["Snow-Covered Swamp", "Snow-Covered Island", "Snow-Covered Forest",
	"Snow-Covered Mountain", "Snow-Covered Plains"]

var _packs: Array[String] = []


func before_each() -> void:
	_packs = Settings.enabled_card_packs().duplicate()
	AdventureSetup.forget()


func after_each() -> void:
	_switch(_packs)
	AdventureSetup.forget()
	CardValue.forget()
	CardShop.forget()
	CardTrade.forget()
	LairEvent.forget()
	AdventurePacks.forget()


## Exactly the packs [param on] switched on in Options › Card Packs.
func _switch(on: Array) -> void:
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != (id in on):
			CardPacks.set_enabled(id, id in on)


## A hero who chose [param selected] on the Embark, with [param deck]
## Forests the deck in use (36: under 40 cards, where a pack card's allowance
## halves to none).
func _hero(selected: Array, deck := 36) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	var ids: Array[String] = []
	ids.assign(selected)
	setup.packs = ids
	var versions := {}
	for id in ids:
		versions[id] = "1"
	var record := setup.resolve(versions)
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	player.cards.clear()
	for i in deck:
		player.cards.append({"card": "Forest", "decks": [0]})
	return player


## A green town or city of [param player]'s world (it sells green and
## colourless cards: Forest and Snow-Covered Forest in its land's place).
func _green_town(player: AdventurePlayer) -> int:
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) in [ShandalarWorld.TOWN, ShandalarWorld.CITY] \
				and CardShop.colors_sold(player.world, slot) == [8]:
			return slot
	return -1


func test_snow_covered_basics_come_four_for_one_amulet() -> void:
	_switch(["pack-3"])
	var player := _hero(["pack-3"])
	var names := CardTrade.for_trader(player, CardTrade.TOWN).map(func(row: Dictionary) -> String: return row["name"])
	for card in SNOW:
		assert_has(names, card, "control: Pack 3 brings " + card)
	player.amulets["green"] = 1
	var asked := CardTrade.offer(player, "Snow-Covered Forest", CardTrade.TOWN, "green")
	assert_eq(int(asked["copies"]), 4, "four at a time, as Forest")
	assert_eq(int(asked["amulets"]), 1, "for one amulet")
	assert_eq(String(asked["words"]), "I'll trade you 4 Snow-Covered Forest for 1 green amulet.")
	assert_eq(int(CardTrade.offer(player, "Forest", CardTrade.TOWN, "green")["copies"]), 4, "control: Forest")
	var had := player.cards.size()
	var paid := CardTrade.pay(player, asked, CardTrade.TOWN, "green")
	assert_true(bool(paid["traded"]), String(paid["said"]))
	assert_eq(player.cards.size(), had + 4)
	assert_eq(String(paid["said"]), "Snow-Covered Forest: 4 more for your cards.")
	assert_eq(int(player.amulets["green"]), 0)
	assert_eq(int(CardTrade.offer(player, "Snow-Covered Island", CardTrade.BAZAAR, "", 200)["copies"]), 4,
		"the Nomad's four too")


func test_no_copy_limit_and_never_dimmed_at_the_trader() -> void:
	_switch(["pack-3"])
	var player := _hero(["pack-3"], 36)
	for i in 12:
		player.cards.append({"card": "Snow-Covered Swamp", "decks": []})
	var f := CardValue.facts(CardRegistry.get_card("Snow-Covered Swamp"))
	var limit := CardShop.copies_allowed(player)
	assert_eq(limit, 1, "control: 36 cards in the deck, no Tome")
	for counts in [{}, {"Snow-Covered Swamp": 12}]:
		assert_eq(CardShop.remaining_copies("Snow-Covered Swamp", f, counts, limit, player.difficulty), 99,
			"a basic land: no copy limit, not halved as a pack card (%s)" % counts)
		assert_eq(CardShop.remaining_copies("Snow-Covered Swamp", f, counts, 3, player.difficulty), 99)
	assert_eq(CardShop.remaining_copies("Swamp", f, {"Swamp": 12}, limit, player.difficulty), 99, "control: Swamp")
	var sentinel := CardValue.facts(CardRegistry.get_card("Adarkar Sentinel"))
	assert_lt(CardShop.remaining_copies("Adarkar Sentinel", sentinel, {}, limit, player.difficulty), 1,
		"control: another pack card has none under 40 cards")
	var pane := CardTradePane.new()
	pane.player = player
	pane.way = CardTrade.BAZAAR
	add_child_autofree(pane)
	# A long list (base and Ice Age) fills a slice a frame.
	for i in 40:
		await get_tree().process_frame
	var list := pane.find_child("TradeCards", true, false) as ItemList
	var at := pane._shown.find("Snow-Covered Swamp")
	assert_gt(at, -1, "control: on the Bazaar's list")
	assert_eq(list.get_item_text(at), "Snow-Covered Swamp-12")
	assert_ne(list.get_item_custom_fg_color(at), PaneStyle.FAINT, "a basic land: never dimmed")
	assert_eq(list.get_item_custom_fg_color(pane._shown.find("Adarkar Sentinel")), PaneStyle.FAINT,
		"control: the other pack card is")


## [param spoils] duel spoils of [param player], meeting after meeting on
## one die: `{picks, snow, pack}` — the Snow-Covered basics and the other
## pack cards among them.
func _spoils(player: AdventurePlayer, spoils: int) -> Dictionary:
	var rows: Array[int] = []
	for row in range(1, CreatureBook.ROWS.size()):
		if CreatureBook.strength(row) > 0:
			rows.append(row)
	var dice := MsvcRandom.new(777)
	var out := {"picks": 0, "snow": 0, "pack": 0}
	var r := 0
	while int(out["picks"]) < spoils:
		var row: int = rows[(r * 7) % rows.size()]
		r += 1
		var meeting := {"row": row, "color": LairDuels.first_color(row), "strength": CreatureBook.strength(row),
			"creature_ante": []}
		for card in DuelSpoils.reward_cards(player, meeting, dice):
			out["picks"] = int(out["picks"]) + 1
			if card in SNOW:
				out["snow"] = int(out["snow"]) + 1
			elif not CardTrade.in_adventure(card):
				out["pack"] = int(out["pack"]) + 1
	return out


## The chance of a small deck's pick to draw the land type: one of the
## reward types the base cards have ([method DuelSpoils._types_in]; without
## the 1997 table no card is an interrupt: one in five, else one in six).
func _land_chance() -> float:
	var present := DuelSpoils._types_in(CardTrade.catalogue())
	var types := 0
	for bit in DuelSpoils.PICK_TYPES:
		types += 1 if present & (1 << bit) != 0 else 0
	return 1.0 / types


## The owner's ruling of 2026-11-03, "In place of a basic land": a deck
## under 40 cards (which may take no pack card) wins a Snow-Covered basic
## only when its pick draws the land type, within Ice Age's own share of
## that pick — never through Ice Age's share of another type (that goes
## back to the base cards). Else, as the only pack cards such a deck could
## be given, they took Pack 3's whole share of the spoils (one in five).
func test_a_small_deck_wins_one_only_in_place_of_a_basic_land() -> void:
	_switch(["pack-3"])
	var player := _hero(["pack-3"], 36)
	var alone := _spoils(player, 4000)
	var expected := _land_chance() * PackShare.share(1) / 100.0
	assert_eq(int(alone["pack"]), 0, "no other pack card for a small deck")
	assert_almost_eq(float(alone["snow"]) / float(alone["picks"]), expected, 0.012,
		"the land type's chance times Ice Age's share: %s" % alone)
	_switch(["pack-2", "pack-3", "pack-4", "pack-5", "pack-6", "pack-7", "pack-8", "pack-9"])
	var eight := _spoils(_hero(["pack-2", "pack-3", "pack-4", "pack-5", "pack-6", "pack-7", "pack-8", "pack-9"],
		36), 4000)
	assert_eq(int(eight["pack"]), 0)
	assert_almost_eq(float(eight["snow"]) / float(eight["picks"]), _land_chance() * PackShare.share(8) / 8.0 / 100.0,
		0.008, "Ice Age's own share of eight, never the others': %s" % eight)


func test_a_deck_of_forty_wins_them_by_the_pack_share() -> void:
	_switch(["pack-3"])
	var forty := _spoils(_hero(["pack-3"], 40), 4000)
	assert_gt(int(forty["pack"]), 400, "control: Ice Age's cards for a 40-card deck: %s" % forty)
	assert_gt(int(forty["snow"]), 0, "and its Snow-Covered basics among them, no copy limit")


## A small deck whose packs have no basic land of their own draws as it
## did, die for die: as a campaign without packs.
func test_a_small_deck_without_pack_basic_lands_draws_as_before() -> void:
	_switch(["pack-2"])
	var plain := _hero([], 36)
	var fallen := _hero(["pack-2"], 36)
	var rows: Array[int] = []
	for row in range(1, CreatureBook.ROWS.size()):
		if CreatureBook.strength(row) > 0:
			rows.append(row)
	var a := MsvcRandom.new(31)
	var b := MsvcRandom.new(31)
	for i in 120:
		var row: int = rows[(i * 7) % rows.size()]
		var meeting := {"row": row, "color": LairDuels.first_color(row), "strength": CreatureBook.strength(row),
			"creature_ante": []}
		assert_eq(DuelSpoils.reward_cards(fallen, meeting, b), DuelSpoils.reward_cards(plain, meeting, a), "meeting %d" % i)
		assert_eq(b.state, a.state, "the same dice, meeting %d" % i)
		if b.state != a.state:
			break


## Each pack its own share of a land's place (the owner's ruling of
## 2026-11-03): Ice Age's share a Snow-Covered basic, every other pack's
## share an ordinary basic land.
func _land_place(selected: Array) -> Dictionary:
	_switch(selected)
	var player := _hero(selected, 60)
	var rules := CardShop._draw_rules(player, _green_town(player))
	var land := MsvcRandom.new(11)
	var drawn := {}
	for i in 8000:
		var card := CardShop._draw(i % 6, true, land, rules)
		drawn[card] = int(drawn.get(card, 0)) + 1
	return drawn


func test_only_the_land_s_place_holds_them_in_ice_age_s_own_share() -> void:
	_switch(["pack-3"])
	var player := _hero(["pack-3"], 60)
	var town := _green_town(player)
	assert_gt(town, -1, "control: a green town")
	var rules := CardShop._draw_rules(player, town)
	var dice := MsvcRandom.new(9)
	for i in 6000:
		var card := CardShop._draw(i % 6, false, dice, rules)
		assert_false(card in SNOW or card in CardShop.LANDS, "no basic land outside the land's place: " + card)
		if card in SNOW or card in CardShop.LANDS:
			break
	for case in [[["pack-3"], 0.20], [["pack-3", "pack-9"], 0.20],
			[["pack-2", "pack-3", "pack-4", "pack-5", "pack-6", "pack-7", "pack-8", "pack-9"], 0.075]]:
		var drawn := _land_place(case[0])
		assert_eq(drawn.keys().size(), 2, "a green town's land place: Forest or Snow-Covered Forest — %s" % drawn)
		assert_almost_eq(float(drawn.get("Snow-Covered Forest", 0)) / 8000.0, float(case[1]), 0.015,
			"Ice Age's own share of %s: %s" % [case[0], drawn])


func test_without_pack_3_in_the_campaign_the_land_s_place_is_as_before() -> void:
	# Pack 3 on in Options, but this campaign chose Pack 2 only.
	_switch(["pack-2", "pack-3"])
	var player := _hero(["pack-2"], 60)
	var town := _green_town(player)
	var rules := CardShop._draw_rules(player, town)
	for card in SNOW:
		assert_false(CardTrade.for_trader(player, CardTrade.TOWN).any(func(row: Dictionary) -> bool:
			return row["name"] == card), card + " is not this campaign's")
	for seed in 300:
		var dice := MsvcRandom.new(seed)
		var old := MsvcRandom.new(seed)
		var lands: Array[String] = ["Forest"]
		assert_eq(CardShop._draw(seed % 6, true, dice, rules), lands[old.below(lands.size())])
		assert_eq(dice.state, old.state, "the same die, cast once")


func test_the_adventure_s_basic_lands_are_the_deck_rules() -> void:
	_switch(["pack-2", "pack-3", "pack-4", "pack-5", "pack-6", "pack-7", "pack-8", "pack-9"])
	var basics := 0
	for card_name in CardRegistry.all_names():
		var card := String(card_name)
		var basic := DeckFormat.is_basic(card)
		basics += 1 if basic else 0
		assert_eq(CardTrade.copies(card), CardTrade.LAND_COPIES if basic else 1, card)
		if basic:
			assert_eq(CardShop.remaining_copies(card, {}, {card: 40}, 2, 3), 99, card + ": no copy limit")
	assert_eq(basics, 10, "Plains … Forest and Ice Age's five")
