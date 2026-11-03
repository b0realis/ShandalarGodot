extends GutTest
## CARD PACKS IN THE ORDINARY ADVENTURE: THE CARDS EACH PACK BRINGS (0.60.14,
## the owner's pack rulings of 2026-11-03). Each pack brings only the cards
## it introduced (Fifth Edition its 147 reprints, at its own rarity unless
## their own pack is chosen too); a card's rarity is its original printing in
## the catalogue that ships with the game, whichever packs are switched on;
## ante cards never stand on a shelf; the strong pack cards are special as
## 1997's power cards are; an old save keeps its packs and follows the rules.

## The strong pack cards the owner named (2026-11-03), and the packs' other Tutors.
const NAMED_STRONG: Array[String] = ["Necropotence", "Force of Will", "Lion's Eye Diamond",
	"Mystical Tutor", "Vampiric Tutor", "Enlightened Tutor", "Worldly Tutor", "Mox Diamond",
	"Survival of the Fittest", "Wasteland", "Lotus Petal", "Hymn to Tourach", "Ancient Tomb",
	"City of Traitors"]

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


## A hero who chose [param selected] on the Embark, with a 60-card deck in
## use (no copy limit near).
func _hero(selected: Array, rule := AdventurePlayer.RULE_MEANT) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	setup.card_rule = rule
	var ids: Array[String] = []
	ids.assign(selected)
	setup.packs = ids
	var versions := {}
	for id in ids:
		versions[id] = "1"
	var record := setup.resolve(versions)
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	player.cards.clear()
	for i in 60:
		player.cards.append({"card": "Forest", "decks": [0]})
	return player


func _names(rows: Array) -> Array[String]:
	var out: Array[String] = []
	for row in rows:
		out.append(String((row as Dictionary)["name"]))
	return out


func _pack_names(rows: Array) -> Array[String]:
	return _names(rows).filter(func(card: String) -> bool: return not CardTrade.in_adventure(card))


func _row(rows: Array, card: String) -> Dictionary:
	for row in rows:
		if String((row as Dictionary)["name"]) == card:
			return row
	return {}


func _town(player: AdventurePlayer) -> int:
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) in [ShandalarWorld.TOWN, ShandalarWorld.CITY]:
			return slot
	return 1


## Every identity a numbered pack introduced (its own scripts), Packs 2–9.
func _identities() -> Dictionary:
	var out := {}
	for card in FallenEmpiresPack.names(): out[card] = FallenEmpiresPack.ID
	for card in IceAgePack.new_names(): out[card] = IceAgePack.ID
	for card in HomelandsPack.new_names(): out[card] = HomelandsPack.ID
	for card in AlliancesPack.new_names(): out[card] = AlliancesPack.ID
	for card in PortalPack.new_names(): out[card] = PortalPack.ID
	for card in MirageBlockPack.new_names(): out[card] = MirageBlockPack.ID
	for card in TempestBlockPack.new_names(): out[card] = TempestBlockPack.ID
	return out


# ------------------------------------------------- ruling 2: its own cards --

func test_a_pack_brings_only_the_cards_it_introduced() -> void:
	_switch(["pack-3", "pack-6", "pack-8"])
	var own := _identities()
	var player := _hero(["pack-8"])
	var cards := _pack_names(CardTrade.for_trader(player, CardTrade.TOWN))
	assert_has(cards, "Lion's Eye Diamond", "Mirage's own card")
	assert_does_not_have(cards, "Alabaster Dragon", "a Portal card the Mirage block reprinted comes with Portal")
	assert_does_not_have(cards, "Flare", "an Ice Age card it reprinted comes with Ice Age")
	assert_true(cards.all(func(card: String) -> bool: return own.get(card, "") == MirageBlockPack.ID),
		"Pack 8 alone: Mirage-block identities only")
	assert_eq(cards.size(), MirageBlockPack.new_names().size())
	player = _hero(["pack-6"])
	assert_does_not_have(_pack_names(CardTrade.for_trader(player, CardTrade.TOWN)), "Mountain Goat",
		"Ice Age's, though Portal reprinted it")
	player = _hero(["pack-6", "pack-8"])
	assert_has(_pack_names(CardTrade.for_trader(player, CardTrade.TOWN)), "Alabaster Dragon",
		"with Portal chosen too it comes")


func test_fifth_edition_brings_its_reprints_at_its_own_rarity_unless_their_pack_is_chosen() -> void:
	# Ice Age and Homelands switched on in Options first: no matter.
	_switch(["pack-3", "pack-4", "pack-7"])
	var player := _hero(["pack-7"])
	var rows := CardTrade.for_trader(player, CardTrade.TOWN)
	assert_eq(_pack_names(rows).size(), FifthEditionPack.SHARED_COUNT, "its 147 Fallen Empires, Ice Age and Homelands cards")
	assert_eq(int(_row(rows, "Pyroblast")["facts"]["rarity"]), 2, "Fifth Edition's uncommon, not Ice Age's common")
	assert_eq(int(CardTrade.offer(player, "Pyroblast", CardTrade.MINE)["amulets"]), 2)
	assert_eq(int(CardTrade.offer(player, "Sengir Autocrat", CardTrade.MINE)["amulets"]), 3, "Fifth Edition's rare")
	var fifth_price := CardShop.price_at(player, _town(player), "Sengir Autocrat")
	player = _hero(["pack-3", "pack-7"])
	assert_eq(int(CardTrade.offer(player, "Pyroblast", CardTrade.MINE)["amulets"]), 1, "Ice Age chosen too: its common")
	assert_eq(int(CardTrade.offer(player, "Sengir Autocrat", CardTrade.MINE)["amulets"]), 3, "Homelands not chosen")
	player = _hero(["pack-4", "pack-7"])
	assert_eq(int(CardTrade.offer(player, "Sengir Autocrat", CardTrade.MINE)["amulets"]), 2, "Homelands' uncommon")
	assert_lt(CardShop.price_at(player, _town(player), "Sengir Autocrat"), fifth_price, "priced at its rarity too")


func test_a_pack_card_s_rarity_is_its_original_printing_whichever_pack_is_on() -> void:
	_switch(["pack-9"])
	assert_eq(CardValue.rarity("Wood Elves"), 3, "Portal's rare, though only Exodus's common is switched on")
	_switch(["pack-6"])
	assert_eq(CardValue.rarity("Mountain Goat"), 1, "Ice Age's common, though only Portal's uncommon is on")
	_switch(["pack-6", "pack-9"])
	assert_eq(CardValue.rarity("Wood Elves"), 3)


# --------------------------------------------- ruling 3: ante off shelves --

func test_ante_cards_never_stand_on_a_shelf_and_elsewhere_are_as_the_base_ante_cards() -> void:
	_switch(["pack-3", "pack-4"])
	var player := _hero(["pack-3", "pack-4"])
	var shelf := _names(CardShop._draw_rules(player, _town(player))["stock"])
	assert_has(shelf, "Necropotence", "control: Ice Age's cards are there")
	for card in ["Amulet of Quoz", "Timmerian Fiends"]:
		assert_does_not_have(shelf, card, card + " is made for ante")
		for pool in [CardTrade.for_trader(player, CardTrade.TOWN), CardTrade.for_trader(player, CardTrade.REWARD),
				LairEvent.reward_pool(player)]:
			assert_has(_names(pool), card, card + " is traded, won and found, as Contract from Below is")
		assert_eq(CardTrade.amulets_for(CardValue.facts(CardRegistry.get_card(card))), 3, "a rare, not special")
	assert_has(_names(CardTrade.for_trader(player, CardTrade.TOWN)), "Contract from Below", "control: the base's ante card")


# ------------------------------------------------- ruling 4: strong cards --

func test_strong_pack_cards_are_special_as_the_base_power_cards() -> void:
	_switch(["pack-2", "pack-3", "pack-4", "pack-5", "pack-6", "pack-7", "pack-8", "pack-9"])
	for card in NAMED_STRONG:
		assert_true(CardRegistry.has_card(card), card)
		var f := CardValue.facts(CardRegistry.get_card(card))
		assert_eq(CardShop.shop_rarity(f), 4, card + " is special")
		assert_eq(CardTrade.amulets_for(f), 4, card + ": 4 amulets")
		assert_eq(DuelSpoils._rarity(card), 4, card + ": the special budget in spoils")
	var player := _hero(["pack-2", "pack-3", "pack-9"])
	var rules := CardShop._draw_rules(player, _town(player))
	rules["sold"] = CardShop.COLOR_BITS.duplicate()
	var strong := (rules["stock"] as Array).filter(func(row: Dictionary) -> bool:
		return String(row["name"]) in NAMED_STRONG)
	assert_gt(strong.size(), 5, "control: on the list of what a shelf may hold")
	rules["stock"] = strong
	rules["base"] = [] as Array[Dictionary]
	rules["packs"] = [strong]
	for place in 6:
		assert_eq(CardShop._draw(place, false, MsvcRandom.new(place + 1), rules), "", "never in a shop place")


# ------------------------------------------------------ ruling 7: old saves --

func test_an_old_save_keeps_its_packs_and_its_cards_and_follows_the_rules() -> void:
	# A hero of 0.50.48–0.50.60, when any pack could join: Ice Age and Tempest.
	_switch(["pack-3", "pack-9"])
	var player := _hero(["pack-3", "pack-9"])
	player.add_card("Necropotence")
	player.add_card("Amulet of Quoz")
	player.add_card("Wood Elves")
	var loaded := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_eq(loaded.packs, player.packs, "its packs kept")
	assert_eq(String(AdventurePacks.resume(loaded)["refusal"]), "")
	for card in ["Necropotence", "Amulet of Quoz", "Wood Elves"]:
		assert_true(loaded.cards.any(func(entry: Dictionary) -> bool: return String(entry["card"]) == card),
			card + " is still the hero's")
	var shelf := _names(CardShop._draw_rules(loaded, _town(loaded))["stock"])
	assert_does_not_have(shelf, "Amulet of Quoz")
	assert_does_not_have(shelf, "Wood Elves", "Portal's card: Portal is not this campaign's")
	assert_eq(int(CardTrade.offer(loaded, "Necropotence", CardTrade.MINE)["amulets"]), 4)


# --------------------------------------------------------- the small fixes --

func test_a_hand_edited_pack_one_or_unknown_pack_adds_nothing() -> void:
	_switch(["pack-1"])
	var player := _hero([])
	player.packs = [{"id": "pack-1", "version": "1"}, {"id": "pack-42", "version": "1"}]
	var base := CardTrade.catalogue()
	assert_eq(AdventurePacks.add_stock(player, base).size(), base.size(), "Pack 1 is never a campaign's")


func test_an_unavailable_shelf_card_names_a_pack_the_campaign_chose() -> void:
	_switch(["pack-3", "pack-7"])
	var player := _hero(["pack-7"])
	var slot := _town(player)
	CardShop.offers(player, slot)
	CardShop.town_record(player, slot)["cards"][1] = "Pyroblast"
	player.gold = 100000
	_switch([])
	var said := String(CardShop.buy(player, slot, 1)["said"])
	assert_string_contains(said, "Pack 7", "Fifth Edition is the campaign's provider of Pyroblast")
	assert_false(said.contains("Pack 3"), said)
