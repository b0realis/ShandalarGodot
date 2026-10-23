extends GutTest
## THE TRADES, THE SHOPS AND THE QUESTS KEPT HONEST (adventure campaign
## 2026-10-23, findings h1-1, h1-3, h1-6, h1-7, h5-5, h5-6, h6-9):
##  - a trade reads the purse again as it is paid ([method CardTrade.pay]):
##    amulets or gold gone since the card was chosen refuse the trade, never
##    a purse below nothing nor a card underpaid (1997's `BuyAnyCardFromTown`
##    read it again too);
##  - a town whose quest was failed offers none — no offer drawn there, no
##    "Begin a Quest", no quest accepted —, and an offer accepted is spent
##    ([Quests]);
##  - a shop stepped straight back into keeps its sold places empty (1997
##    redrew a shop only in a town other than the last one, visitLocation.c
##    1689), while a place never filled is filled at once ([CardShop]);
##  - the shop admits a land other than a basic one where the 1997 program's
##    flags let it through, and only the 1997 table does (without it, the
##    rules before);
##  - the shop's cards are read without deriving every card of every pack,
##    a card's facts are read once ([method CardValue.facts]), and a shop's
##    draw counts the deck in use once — the same rows and the same cards
##    drawn as before, measured;
##  - the Nomad charges a colourless card half again, as 1997 did.

var player: AdventurePlayer


func before_each() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))


func after_each() -> void:
	# The tables some tests put in place of the imported ones.
	CardValue.forget()
	CardShop.forget()
	CardTrade.forget()
	CardHints.forget()


func _sites(kind: int) -> Array[int]:
	var out: Array[int] = []
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) == kind:
			out.append(slot)
	return out


func _twin(of: AdventurePlayer) -> AdventurePlayer:
	return AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(of.to_dict())))


# ----------------------------------------------- h1-1: the purse, again --

func test_a_town_trade_reads_the_amulets_again_as_it_is_paid() -> void:
	player.amulets = {"black": 0, "blue": 0, "green": 0, "red": 2, "white": 0}
	var cards := player.cards.size()
	var asked := CardTrade.offer(player, "Serra Angel", CardTrade.TOWN, "red")
	assert_true(asked["afford"], "two red amulets held as the card is chosen")
	player.amulets["red"] = 1
	var done := CardTrade.pay(player, asked, CardTrade.TOWN, "red")
	assert_false(done["traded"], "one gone before Yes: no trade")
	assert_eq(done["said"], CardTrade.AFFORD)
	assert_eq(int(player.amulets["red"]), 1, "never below what is held")
	assert_eq(player.cards.size(), cards, "and no card")
	player.amulets["red"] = 0
	assert_false(CardTrade.pay(player, asked, CardTrade.TOWN, "red")["traded"])
	assert_eq(int(player.amulets["red"]), 0, "never -2")


func test_the_diamond_mine_never_gives_a_card_underpaid() -> void:
	player.amulets = {"black": 1, "blue": 1, "green": 0, "red": 0, "white": 0}
	var cards := player.cards.size()
	var asked := CardTrade.offer(player, "Serra Angel", CardTrade.MINE)
	assert_eq(int(asked["amulets"]), 2)
	assert_true(asked["afford"])
	player.amulets["blue"] = 0
	var done := CardTrade.pay(player, asked, CardTrade.MINE)
	assert_false(done["traded"], "one amulet left of the two asked: no trade")
	assert_eq(done["said"], CardTrade.AFFORD)
	assert_eq(player.amulet_count(), 1, "the one left kept")
	assert_eq(player.cards.size(), cards, "no card for half the price")


func test_the_nomad_reads_the_gold_again_and_the_purse_not_the_flag() -> void:
	player.gold = 200
	var asked := CardTrade.offer(player, "Grizzly Bears", CardTrade.BAZAAR, "", 135)
	assert_true(asked["afford"])
	player.gold = 100
	assert_false(CardTrade.pay(player, asked, CardTrade.BAZAAR)["traded"], "the gold spent meanwhile")
	assert_eq(player.gold, 100)
	# The live purse decides both ways: gold found since is gold to pay with.
	asked = CardTrade.offer(player, "Grizzly Bears", CardTrade.BAZAAR, "", 135)
	assert_false(asked["afford"])
	player.gold = 135
	assert_true(CardTrade.pay(player, asked, CardTrade.BAZAAR)["traded"])
	assert_eq(player.gold, 0)


# ------------------------------------------- h1-3: a town that refuses --

## A village that draws an offer on [param hero]'s arrival, or -1.
func _village_with_an_offer(hero: AdventurePlayer) -> int:
	for village in _sites(ShandalarWorld.VILLAGE):
		var probe := _twin(hero)
		CardTrade.arrive(probe, village)
		Quests.arrive(probe, village)
		if not probe.quest_offer.is_empty():
			return village
	return -1


func test_a_town_whose_quest_failed_draws_no_offer_and_offers_none() -> void:
	player.amulets = {"black": 3, "blue": 3, "green": 3, "red": 3, "white": 3}
	var village := _village_with_an_offer(player)
	assert_gte(village, 0, "a village that gives a quest")
	var refusing := _twin(player)
	TownStatus.put(refusing.world, village, TownStatus.NO_QUESTS)
	for hero in [player, refusing]:
		CardTrade.arrive(hero, village)
		Quests.arrive(hero, village)
	assert_false(player.quest_offer.is_empty(), "the twin that never failed is offered one")
	assert_true(refusing.quest_offer.is_empty(), "the town that refuses keeps none")
	assert_eq(refusing.dice, player.dice, "the dice drawn as 1997 drew them all the same")
	# An offer left over from before is not offered there either.
	refusing.quest_offer = player.quest_offer.duplicate()
	refusing.quest_timer += 1000
	assert_false(Quests.offered(refusing, village), "no Begin a Quest")
	assert_eq(Quests.accept(refusing, village), "", "and no quest accepted")
	assert_false(Quests.has_quest(refusing))


func test_a_quest_failed_is_never_offered_again_there() -> void:
	var village := _sites(ShandalarWorld.VILLAGE)[0]
	var destination := -1
	for slot in _sites(ShandalarWorld.TOWN):
		if not TownStatus.linked(player.world, slot):
			destination = slot
			break
	player.quest_offer = {"type": Quests.LETTER_LINK, "destination": destination, "color": 4, "at": village}
	assert_true(Quests.offered(player, village))
	assert_eq(Quests.accept(player, village), "You have 4 days to complete the quest.")
	assert_true(player.quest_offer.is_empty(), "the offer taken is spent [ours]")
	player.quest_timer = int(player.quest["deadline"])
	assert_ne(Quests.check_deadline(player), "", "the quest lost")
	assert_true(TownStatus.refuses_quests(player.world, village))
	# The probe's path: the same offer back after the town's wait — refused.
	player.quest_offer = {"type": Quests.LETTER_LINK, "destination": destination, "color": 4, "at": village}
	player.quest_timer += (player.difficulty + 3) * Quests.QUEST_WAIT + 1
	assert_false(Quests.offered(player, village), "the village turns the hero away for good")
	assert_eq(Quests.accept(player, village), "", "accept again: nothing")
	assert_false(Quests.has_quest(player))


func test_an_offer_taken_does_not_come_back() -> void:
	var village := _sites(ShandalarWorld.VILLAGE)[0]
	var destination := -1
	for slot in _sites(ShandalarWorld.TOWN):
		if not TownStatus.linked(player.world, slot):
			destination = slot
			break
	player.quest_offer = {"type": Quests.LETTER_AMULET, "destination": destination, "color": 2, "at": village}
	Quests.accept(player, village)
	Quests.complete_at(player, destination)
	assert_false(Quests.has_quest(player), "done")
	player.quest_timer += (player.difficulty + 3) * Quests.QUEST_WAIT + 1
	assert_false(Quests.offered(player, village), "the letter delivered is not asked for again")


func test_accept_takes_only_the_offer_made_here() -> void:
	var village := _sites(ShandalarWorld.VILLAGE)[0]
	var other := _sites(ShandalarWorld.VILLAGE)[1]
	player.quest_offer = {"type": Quests.LETTER_AMULET, "destination": _sites(ShandalarWorld.TOWN)[0],
		"color": 2, "at": village}
	assert_eq(Quests.accept(player, other), "", "another village's offer")
	assert_false(Quests.has_quest(player))
	assert_false(player.quest_offer.is_empty(), "still waiting where it was made")


# ------------------------------------- h1-6: stepping straight back in --

func test_a_shop_stepped_straight_back_into_keeps_its_sold_places_empty() -> void:
	var town := _sites(ShandalarWorld.TOWN)[0]
	var other := _sites(ShandalarWorld.TOWN)[1]
	player.last_town = other
	var cards := CardShop.offers(player, town)
	assert_ne(cards[1], "")
	player.gold = 100000
	assert_true(CardShop.buy(player, town, 1)["bought"])
	player.last_town = town
	player.quest_timer += 1000
	assert_eq(CardShop.offers(player, town)[1], "", "back in at once: the place sold stays empty (1997)")
	player.last_town = other
	assert_ne(CardShop.offers(player, town)[1], "", "from another town, its wait over: a new card")


func test_a_place_never_filled_is_filled_whichever_town_was_last() -> void:
	var village := _sites(ShandalarWorld.VILLAGE)[0]
	player.last_town = -1
	assert_eq(CardShop.offers(player, village).size(), 4)
	player.last_town = village
	player.world_magics.append("Haggler's Coin")
	var cards := CardShop.offers(player, village)
	assert_eq(cards.size(), 5, "Haggler's Coin: one more place")
	assert_ne(cards[4], "", "and it is filled at once")


# ------------------------------------- h1-7: lands as 1997 let them in --

## The 1997 table's rows for two lands and a power card, in place of the
## imported table (`adventure_cards.json`'s fields).
func _a_1997_table() -> Dictionary:
	var land := {"ai": 2, "cc0": 0, "cc1": 0, "color": 1, "exp": 1, "extra": 0x1401, "power": 0,
		"rarity": 3, "static": 0, "tough": 0, "type": CardValue.LAND, "vanilla": false}
	var library := land.duplicate()
	library["exp"] = 4
	var swamp := land.duplicate()
	swamp["color"] = 2
	swamp["extra"] = 0x1000
	swamp["rarity"] = 1
	return {"Mishra's Factory": land, "Library of Alexandria": library, "Swamp": swamp}


func _names(rows: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for row in rows:
		out.append(String(row["name"]))
	return out


func test_a_land_the_1997_flags_let_through_is_sold() -> void:
	CardRegistry.ensure_loaded()
	CardValue.forget()
	CardValue._imported_read = true
	CardValue._imported = _a_1997_table()
	CardShop.forget()
	var names := _names(CardShop.stock())
	assert_true("Mishra's Factory" in names, "of the base set (0x01), no 0x900/0x180: in the shop")
	assert_false("Library of Alexandria" in names, "Arabian Nights (0x04): never")
	assert_false("Swamp" in names, "a basic land only by its own place [ours]")
	for card_name in names:
		var data := CardRegistry.get_card(card_name)
		if data.is_land():
			assert_false(bool(CardValue.facts(data).get("derived", true)), card_name + ": a land only by the 1997 table")


func test_without_the_1997_table_no_land_is_sold() -> void:
	CardRegistry.ensure_loaded()
	CardValue.forget()
	CardValue._imported_read = true
	CardValue._imported = {}
	CardShop.forget()
	for row in CardShop.stock():
		assert_false(CardRegistry.get_card(String(row["name"])).is_land(), String(row["name"]))


# ----------------------------------------------- h5-5: the stock, read --

## THE STOCK THE SLOW WAY — every card's facts read first, then the rules:
## the rows [method CardShop.stock] must give.
func _stock_by_hand() -> Array[Dictionary]:
	var treasures: Array[String] = []
	for row in ShandalarWorld.DUNGEON_CARDS:
		treasures.append(String(row[1]))
	var names: Array = CardRegistry.all_names()
	names.sort()
	var rows: Array[Dictionary] = []
	for card_name in names:
		var name_text := String(card_name)
		var data := CardRegistry.get_card(name_text)
		if data == null or name_text in CardShop.LANDS:
			continue
		var own := CardValue.original(name_text)
		var f: Dictionary
		if own.is_empty():
			f = CardValue.derive(data)
			if data.is_land() or not CardValue.is_base(name_text) or name_text in treasures \
					or name_text in DeckFormat.BANNED or name_text in DeckFormat.RESTRICTED:
				continue
		else:
			f = own.duplicate()
			f["derived"] = false
			if int(f.get("exp", 0)) & 0xC1 == 0 or int(f.get("extra", 0)) & 0x980 != 0:
				continue
		rows.append({"name": name_text, "facts": f})
	return rows


func test_the_stock_reads_the_facts_of_its_own_rows_only() -> void:
	CardRegistry.ensure_loaded()
	CardValue.forget()
	CardShop.forget()
	var rows := CardShop.stock()
	var names := _names(rows)
	assert_gt(names.size(), 300, "the base set's cards")
	for card_name in CardValue._facts_read:
		assert_true(card_name in names, "%s: its facts read, and not in the shop" % card_name)
	var by_hand := _stock_by_hand()
	assert_eq(names, _names(by_hand), "the same rows")
	for i in mini(rows.size(), by_hand.size()):
		assert_eq(rows[i]["facts"], by_hand[i]["facts"], String(rows[i]["name"]) + ": the same facts")


func test_a_card_s_facts_are_read_once() -> void:
	CardRegistry.ensure_loaded()
	CardValue.forget()
	var angel := CardRegistry.get_card("Serra Angel")
	var first := CardValue.facts(angel)
	assert_true(CardValue._facts_read.has("Serra Angel"), "kept")
	assert_same(CardValue.facts(angel), first, "read once")
	assert_true(first.is_read_only(), "and no caller can change what the next one reads")
	var own := CardValue.original("Serra Angel")
	if own.is_empty():
		assert_eq(first, CardValue.derive(angel), "read off the card")
	else:
		var expected := own.duplicate()
		expected["derived"] = false
		assert_eq(first, expected, "the 1997 program's")
	CardValue.forget()
	assert_false(CardValue._facts_read.has("Serra Angel"), "forgotten with the table")
	# A card made apart from the registry is read for itself, never taken
	# for the registry's card of its name nor kept under it (a name the 1997
	# table does not have: that table is read by name).
	var name_text := ""
	for card_name in CardRegistry.all_names():
		if CardValue.original(String(card_name)).is_empty():
			name_text = String(card_name)
			break
	var registry_card := CardRegistry.get_card(name_text)
	var kept := CardValue.facts(registry_card)
	var other := CardData.new(name_text, "{3}{W}{W}", Mtg.CardType.CREATURE).pt(9, 9)
	var its_own := CardValue.facts(other)
	assert_eq(int(its_own["power"]), 9, "%s made apart: its own facts" % name_text)
	assert_same(CardValue.facts(registry_card), kept, "the registry's card still kept")
	CardValue.forget()
	CardValue.facts(other)
	assert_false(CardValue._facts_read.has(name_text), "not the registry's card: not kept")


# ------------------------------------------- h5-6: the deck, counted once --

func test_the_deck_in_use_is_counted_once_as_by_card() -> void:
	CardRegistry.ensure_loaded()
	var stock := CardShop.stock()
	for i in 200:
		player.cards.append({"card": String(stock[i % 40]["name"]), "decks": [player.current_deck]})
	var counts := CardShop.deck_counts(player)
	for row in stock:
		var card_name := String(row["name"])
		assert_eq(int(counts.get(card_name, 0)), CardShop.in_deck(player, card_name), card_name)
	var size := 0
	for card_name in counts:
		size += int(counts[card_name])
	assert_eq(CardShop.allowed_for(player, size), CardShop.copies_allowed(player))


## THE OLD DRAW, by hand: each place walking the collection for each card
## ([method CardShop.in_deck]) — the cards [method CardShop.offers] must draw.
func _offers_by_hand(hero: AdventurePlayer, slot: int) -> Array[String]:
	var size := CardShop.size_of(hero, int(hero.world.sites[slot]["type"]))
	var sold := CardShop.colors_sold(hero.world, slot)
	var limit := CardShop.copies_allowed(hero)
	var out: Array[String] = []
	var dice := MsvcRandom.new(hero.dice)
	var land := dice.below(size)
	for place in size:
		if place == land:
			var lands: Array[String] = []
			for i in CardShop.COLOR_BITS.size():
				if CardShop.COLOR_BITS[i] in sold:
					lands.append(CardShop.LANDS[i])
			out.append(lands[dice.below(lands.size())] if not lands.is_empty() else "")
			continue
		var fitting: Array[String] = []
		for row in CardShop.stock():
			var f: Dictionary = row["facts"]
			var bits := int(f.get("color", CardValue.COLORLESS))
			if bits != CardValue.COLORLESS and not CardValue.first_color(bits) in sold:
				continue
			if place % 2 == 1 and int(f.get("type", 0)) & CardValue.ARTIFACT != 0:
				continue
			if CardShop.shop_rarity(f) > place % 3 + 1:
				continue
			if CardShop.in_deck(hero, String(row["name"])) >= limit:
				continue
			fitting.append(String(row["name"]))
		out.append(fitting[dice.below(fitting.size())] if not fitting.is_empty() else "")
	hero.dice = dice.state
	return out


func test_a_shop_drawn_for_a_big_collection_draws_the_same_cards() -> void:
	CardRegistry.ensure_loaded()
	var stock := CardShop.stock()
	# Three of each of 200 of the shop's cards in the deck in use: none of
	# those may be drawn (the limit is three from 60 cards).
	for i in 600:
		player.cards.append({"card": String(stock[i % 200]["name"]), "decks": [player.current_deck]})
	for slot in _sites(ShandalarWorld.CITY).slice(0, 3) + _sites(ShandalarWorld.VILLAGE).slice(0, 3):
		var twin := _twin(player)
		var drawn := CardShop.offers(player, slot)
		assert_eq(drawn, _offers_by_hand(twin, slot), "the same cards at %d" % slot)
		assert_eq(player.dice, twin.dice, "the same dice")


func test_a_shop_drawn_for_a_huge_collection_stays_quick() -> void:
	CardRegistry.ensure_loaded()
	var stock := CardShop.stock()
	for i in 30000:
		player.cards.append({"card": String(stock[i % stock.size()]["name"]), "decks": [player.current_deck]})
	var city := _sites(ShandalarWorld.CITY)[0]
	var began := Time.get_ticks_msec()
	var drawn := CardShop.offers(player, city)
	var took := Time.get_ticks_msec() - began
	assert_eq(drawn.size(), 6)
	# Walking the 30,000 cards for each card of each place took seconds; once
	# per draw it is a few hundredths of one.
	assert_lt(took, 600, "a city's six places drawn in %d ms" % took)


# ------------------------------------------- h6-9: the Nomad's colour --

func test_the_nomad_charges_a_colourless_card_half_again() -> void:
	CardRegistry.ensure_loaded()
	var tome := CardRegistry.get_card("Jayemdae Tome")
	var f := CardValue.facts(tome)
	assert_eq(int(f["color"]), CardValue.COLORLESS)
	var value := CardValue.price_of(f) * 4 * 3 / 2
	value = value * 1250 / 750
	var expected := maxi(clampi(value / 50 * 5, 5, 1000), CardTrade.amulets_for(f) * 50)
	assert_eq(CardTrade.bazaar_price(player, tome, 0), expected,
		"no colour of the land: half again, as in a town (`BuyAnyCardFromTown`)")
	assert_eq(CardValue.land_markup(100, CardValue.COLORLESS, 0x10), 150, "colourless: half again")
	assert_eq(CardValue.land_markup(100, 0x10, 0x10), 100, "of the land's colour: its price")
	assert_eq(CardValue.land_markup(100, 0x08, 0x10), 150, "a colour that goes with it: half again")
	assert_eq(CardValue.land_markup(100, 0x20, 0x10), 200, "else twice")
	assert_eq(CardValue.land_markup(100, 0, 0x10), 200, "no colour at all, in a town: twice (1997)")


# ------------------------------- h4-5: a quest to a town that is not there --

func test_a_reminder_of_a_quest_to_no_such_town_falls_to_the_gift() -> void:
	var village := _sites(ShandalarWorld.VILLAGE)[0]
	player.quest = {"type": Quests.LETTER_LINK, "destination": 999, "giver": village, "color": 1,
		"data": 0, "deadline": player.quest_timer + 60}
	assert_eq(WiseMan.reminder(player), "", "a save's quest to slot 999: nothing to remind of")
	# The talk replayed in the same town, a reminder due: the gift instead.
	player.last_town = village
	player.wise_man = {"stage": WiseMan.STAGE_GIFT, "remind": true}
	var talk := WiseMan.speak(player, village)
	var pages: PackedStringArray = talk["pages"]
	assert_gt(pages.size(), 0, "the wise man speaks")
	for page in pages:
		assert_ne(page, "", "no empty page")
	WiseMan.forget()


func test_an_offer_to_no_such_town_is_not_offered() -> void:
	var village := _sites(ShandalarWorld.VILLAGE)[0]
	player.quest_offer = {"type": Quests.LETTER_AMULET, "destination": 999, "color": 2, "at": village}
	assert_false(Quests.offered(player, village), "a save's offer to slot 999")
	assert_eq(Quests.accept(player, village), "")
	assert_false(Quests.has_quest(player))


# ------------------- the lead's ruling: the seller's hint, back in at once --

func test_back_in_the_town_last_visited_the_seller_has_no_hint() -> void:
	var town := _sites(ShandalarWorld.TOWN)[0]
	var other := _sites(ShandalarWorld.TOWN)[1]
	player.last_town = other
	var offered := ""
	for card_name in CardShop.offers(player, town):
		if card_name != "" and not card_name in CardShop.LANDS:
			offered = card_name
			break
	CardHints.forget()
	CardHints._read = true
	# Two hints for the card: one of them is drawn with the dice.
	var owned := String(player.cards[0]["card"])
	CardHints._hints = [{"first": offered, "second": owned, "levels": 0xF, "text": "win the day!"},
		{"first": offered, "second": owned, "levels": 0xF, "text": "win the night!"}]
	var twin := _twin(player)
	CardHints.arrive(player, town)
	assert_eq(String(CardHints.current(player, town).get("card", "")), offered, "from another town: a hint")
	var dice := player.dice
	assert_ne(dice, twin.dice, "drawn with the dice")
	player.last_town = town
	CardHints.arrive(player, town)
	assert_eq(CardHints.current(player, town), {}, "straight back in: none (1997, visitLocation.c 1685)")
	assert_eq(player.dice, dice, "and no dice drawn")
	player.last_town = other
	CardHints.arrive(player, town)
	assert_false(CardHints.current(player, town).is_empty(), "from another town again: a hint")


# ------------------------- the lead's ruling: the tables follow the pool --

func test_the_card_tables_are_read_again_when_the_card_pool_changes() -> void:
	CardRegistry.ensure_loaded()
	for forget in [CardValue.forget, CardShop.forget, CardTrade.forget, CardRiddle.forget, CardHints.forget]:
		forget.call()
	# Tables as a pool now gone would have left them: a 1997 table that
	# lets Library of Alexandria into the shops and keeps Serra Angel out of
	# everything, and a seller's hint of its own.
	var stand_in := {"ai": 2, "cc0": 0, "cc1": 0, "color": 1, "exp": 1, "extra": 0, "power": 0,
		"rarity": 2, "static": 0, "tough": 0, "type": CardValue.LAND, "vanilla": false}
	var kept_out := stand_in.duplicate()
	kept_out["exp"] = 4
	kept_out["extra"] = 0x800
	kept_out["type"] = CardValue.CREATURE
	CardValue._imported_read = true
	CardValue._imported = {"Library of Alexandria": stand_in, "Serra Angel": kept_out}
	CardHints._read = true
	CardHints._hints = [{"first": "Serra Angel", "second": "", "levels": 0xF, "text": "a pool gone"}]
	var stale_hints := CardHints.hints().duplicate()
	assert_true("Library of Alexandria" in _names(CardShop.stock()))
	assert_false("Serra Angel" in _names(CardShop.stock()))
	assert_false("Serra Angel" in _names(CardTrade.catalogue()))
	var riddles: Array[String] = []
	for row in CardRiddle.pool():
		riddles.append(String(row["name"]))
	assert_false("Serra Angel" in riddles)
	# The pool rebuilt, as a pack turned on or off rebuilds it.
	var revision := CardRegistry.revision
	CardRegistry.unload()
	CardRegistry.ensure_loaded()
	assert_gt(CardRegistry.revision, revision, "a new pool")
	assert_false("Library of Alexandria" in _names(CardShop.stock()), "the shops' stock read again")
	assert_true("Serra Angel" in _names(CardShop.stock()))
	assert_true("Serra Angel" in _names(CardTrade.catalogue()), "the trades' cards read again")
	riddles.clear()
	for row in CardRiddle.pool():
		riddles.append(String(row["name"]))
	assert_true("Serra Angel" in riddles, "the riddles' cards read again")
	assert_ne(CardHints.hints(), stale_hints, "the seller's hints read again")
	assert_ne(int(CardValue.original("Library of Alexandria").get("exp", 0)), 1, "the 1997 table read again")
	assert_false(bool(CardValue.facts(CardRegistry.get_card("Serra Angel")).has("extra")
		and int(CardValue.facts(CardRegistry.get_card("Serra Angel"))["extra"]) == 0x800), "and the facts")
