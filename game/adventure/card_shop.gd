class_name CardShop
extends RefCounted
## A TOWN'S CARDS FOR SALE (the owner, 2026-10-23: *"lets build the card
## shop … study how, which cards are available where"*). The 1997 game's
## shop, read in `RunTownServicesMenu` (1.3 004ef1ea) and
## `RunTownBuyCardsScreen` (004f0d09):
##  - a village offers 4 cards, a town 5, a city 6 — one more with
##    Haggler's Coin;
##  - they are drawn on the hero's first visit and stay; a card bought
##    leaves its place empty until the quest clock has gone
##    `(difficulty + 3) · 5` steps past a time set at the purchase (now and
##    up to four times `difficulty + 2` more), when a new card is drawn there
##    — on a visit to a town other than the last one: 1997 drew a shop only
##    then (visitLocation.c 1689), so a hero who steps straight back in finds
##    the places sold still empty;
##  - each time cards are drawn one place, at random, is a basic land;
##  - the colours are the town's land's (`GetWorldTileMagicMask`): a black,
##    green or white town sells its colour, a blue one black and white as
##    well, a red one green and black as well — and colourless cards
##    everywhere; a card of two colours counts as its first of black, blue,
##    green, red, white;
##  - the places alternate what they may hold: the 1st, 4th … common only,
##    the 2nd, 5th … up to uncommon, the 3rd, 6th … up to rare; the 2nd,
##    4th and 6th never an artifact;
##  - only the base set; never a card made for ante, a dungeon's treasure,
##    a power card or a restricted one ([method stock]) — with the 1997
##    program imported, that lets two lands other than basic ones through,
##    Mishra's Factory and Strip Mine (without it, no land but the basic
##    ones); a basic land only by its own place [ours: 1997's other places
##    could draw one too];
##  - never a card the hero could not put in the deck in use: no more
##    copies there than the deck's size allows (one under 40 cards, two from
##    40, three from 60, one more with Tome of Enlightenment).
## A card bought joins the hero's cards, in no deck (`deck[]`'s 0x4000).
## The dice are the adventure's: 1997 drew any card and threw back the ones
## that did not fit, these draw among those that fit — the same odds.

## The basic lands by colour, black to white (the 1.3 card table's first
## five rows).
const LANDS: Array[String] = ["Swamp", "Island", "Forest", "Mountain", "Plains"]
const COLOR_BITS: Array[int] = [2, 4, 8, 16, 32]
## Each colour's companions in a shop (`is_card_color_compatible_with_mask`
## at level 1 for black, green and white, 3 for blue and red).
const SELLS := {2: [2], 4: [4, 2, 32], 8: [8], 16: [16, 8, 2], 32: [32]}
const POOR := "Not enough gold for that card."
## A place never filled yet: its wait long over.
const NEVER_FILLED := -0x7fffffff

## The cards a shop may hold, read once for the card pool as it stands:
## `{name, facts}`.
static var _stock: Array[Dictionary] = []
## The card pool's revision the stock was read against (−1: not yet).
static var _read_at := -1


## How many cards a site of [param site_type] (1 village … 3 city) offers.
static func size_of(player: AdventurePlayer, site_type: int) -> int:
	return site_type + 3 + (1 if player.owns("Haggler's Coin") else 0)


## The colours of the land site [param slot] stands on (1997 colour bits).
static func town_colors(world: ShandalarWorld, slot: int) -> int:
	var site: Dictionary = world.sites[slot]
	return ShandalarWorld.magic_mask(world.terrain(int(site["x"]), int(site["y"])))


## The card colours site [param slot] sells (1997 colour bits; colourless
## cards besides).
static func colors_sold(world: ShandalarWorld, slot: int) -> Array[int]:
	var sold: Array[int] = []
	var mask := town_colors(world, slot)
	for bit in COLOR_BITS:
		if mask & bit != 0:
			for hue in SELLS[bit]:
				if not hue in sold:
					sold.append(hue)
	return sold


## THE CARDS ON OFFER at site [param slot], drawn or restocked as the
## quest clock now stands ([method _to_fill]): card names, "" for a place
## sold and not yet filled again.
static func offers(player: AdventurePlayer, slot: int) -> Array[String]:
	var shop := town_record(player, slot)
	var cards: Array = shop["cards"]
	var restock: Array = shop["restock"]
	var wanted := size_of(player, int(player.world.sites[slot]["type"]))
	while cards.size() < wanted:
		cards.append("")
		restock.append(NEVER_FILLED)
	var empty := _to_fill(player, slot, cards, restock)
	if not empty.is_empty():
		var rules := _draw_rules(player, slot)
		var dice := MsvcRandom.new(player.dice)
		var land := dice.below(cards.size())
		for i in empty:
			cards[i] = _draw(i, i == land, dice, rules)
		player.dice = dice.state
	var out: Array[String] = []
	for card in cards:
		out.append(String(card))
	return out


## The places of [param cards] to draw now: a place never filled, at once;
## a place sold, once the quest clock is `(difficulty + 3) · 5` steps past
## its time in [param restock] — and only on a visit to a town other than
## the last one ([member AdventurePlayer.last_town]; `RunTownServicesMenu`
## drew a shop only then, visitLocation.c 1689).
static func _to_fill(player: AdventurePlayer, slot: int, cards: Array, restock: Array) -> Array[int]:
	var wait := (clampi(player.difficulty, 0, 3) + 3) * 5
	var fresh := player.last_town != slot
	var empty: Array[int] = []
	for i in cards.size():
		if String(cards[i]) != "":
			continue
		var at := int(restock[i])
		if at == NEVER_FILLED or (fresh and player.quest_timer - at >= wait):
			empty.append(i)
	return empty


## BUY offer [param index] of site [param slot]: `{bought, said, price}`.
static func buy(player: AdventurePlayer, slot: int, index: int) -> Dictionary:
	var cards := offers(player, slot)
	if index < 0 or index >= cards.size() or cards[index] == "":
		return {"bought": false, "said": "That card is sold.", "price": 0}
	var card_name := cards[index]
	var price := price_at(player, slot, card_name)
	if player.gold < price:
		return {"bought": false, "said": POOR, "price": price}
	player.gold -= price
	player.cards.append({"card": card_name, "decks": []})
	var shop := town_record(player, slot)
	shop["cards"][index] = ""
	var dice := MsvcRandom.new(player.dice)
	shop["restock"][index] = player.quest_timer + dice.below(5) * (clampi(player.difficulty, 0, 3) + 2)
	player.dice = dice.state
	CardHints.bought(player, slot, card_name)
	return {"bought": true, "said": "You buy %s for %d gold." % [card_name, price], "price": price}


## What [param card_name] costs at site [param slot] ([method CardValue.buy_price]).
static func price_at(player: AdventurePlayer, slot: int, card_name: String) -> int:
	if not CardRegistry.has_card(card_name):
		return 0
	return CardValue.buy_price(CardRegistry.get_card(card_name), int(player.world.sites[slot]["type"]),
		town_colors(player.world, slot))


## What site [param slot] pays for [param card_name] ([method CardValue.sell_price]).
static func sell_price_at(player: AdventurePlayer, slot: int, card_name: String) -> int:
	if not CardRegistry.has_card(card_name):
		return 0
	return CardValue.sell_price(CardRegistry.get_card(card_name), int(player.world.sites[slot]["type"]),
		town_colors(player.world, slot))


## WHAT THE PLACES PAY FOR [param card_name], AT LEAST AND AT MOST [ours,
## the adventure deck builder's worth strip]: [method CardValue.sell_price]
## over every place that buys cards (village, town, city: each has Edit
## deck/Sell cards) on the colours of every land the world is made of
## ([constant ShandalarWorld.LANDS_MADE], [method ShandalarWorld.magic_mask]:
## a two-colour mask no generated land has would price a gold card or a
## dual land at a match no place pays — the bug pass after the campaign,
## r4-2).
## It reads no world, so it tells nothing of places not found. (0, 0) for a
## card the registry lacks.
static func sell_range(card_name: String) -> Vector2i:
	if not CardRegistry.has_card(card_name):
		return Vector2i.ZERO
	var data := CardRegistry.get_card(card_name)
	var least := -1
	var most := 0
	for code in ShandalarWorld.LANDS_MADE:
		var land := ShandalarWorld.magic_mask(code)
		for site_type in [ShandalarWorld.VILLAGE, ShandalarWorld.TOWN, ShandalarWorld.CITY]:
			var price := CardValue.sell_price(data, site_type, land)
			least = price if least < 0 else mini(least, price)
			most = maxi(most, price)
	return Vector2i(maxi(least, 0), most)


## THE BEST PRICE THE HERO KNOWS OF for [param card_name] [ours]: the place
## the hero has visited ([method TownStatus.visited]) and no wizard rules
## that pays the most — `{"slot", "name", "price"}`, the first such place
## on a tie — or empty when the hero has been to none.
static func best_known_sale(player: AdventurePlayer, card_name: String) -> Dictionary:
	var best := {}
	if player.world == null or not CardRegistry.has_card(card_name):
		return best
	for slot in player.world.sites.size():
		var site_type := int(player.world.sites[slot]["type"])
		if site_type < ShandalarWorld.VILLAGE or site_type > ShandalarWorld.CITY:
			continue
		if not TownStatus.visited(player.world, slot) or TownStatus.ruler(player.world, slot) != 0:
			continue
		var price := sell_price_at(player, slot, card_name)
		if best.is_empty() or price > int(best["price"]):
			best = {"slot": slot, "name": WorldNames.site_name(player.world, slot), "price": price}
	return best


## TOWN [param slot]'S RECORD, kept with the adventure ([member
## AdventurePlayer.shops], made on first ask): its cards for sale and their
## restock times (`cards`, `restock`), and what the town's other rules keep
## there — the colour of amulet it wants this visit and its last trade
## ([CardTrade]: `want`, `traded`), the seller's hint ([CardHints]: `hint`).
static func town_record(player: AdventurePlayer, slot: int) -> Dictionary:
	var key := str(slot)
	if not player.shops.has(key):
		player.shops[key] = {"cards": [], "restock": []}
	return player.shops[key]


## WHAT ONE DRAW AT SITE [param slot] READS, once for all its places: the
## colours sold, the deck in use counted by card ([method deck_counts]) and
## how many copies of a card it may hold.
static func _draw_rules(player: AdventurePlayer, slot: int) -> Dictionary:
	var held := deck_counts(player)
	var size := 0
	for card_name in held:
		size += int(held[card_name])
	return {"sold": colors_sold(player.world, slot), "held": held, "limit": allowed_for(player, size)}


## One card for place [param place]: a basic land of a colour the town
## sells when [param land], else a card the rules allow — of the colours
## sold (or colourless), up to the place's rarity, no artifact in an even
## place, not one the deck in use is full of ([param rules]:
## [method _draw_rules]).
static func _draw(place: int, land: bool, dice: MsvcRandom, rules: Dictionary) -> String:
	var sold: Array[int] = rules["sold"]
	if land:
		var lands: Array[String] = []
		for i in COLOR_BITS.size():
			if COLOR_BITS[i] in sold:
				lands.append(LANDS[i])
		return lands[dice.below(lands.size())] if not lands.is_empty() else ""
	var most := place % 3 + 1
	var held: Dictionary = rules["held"]
	var limit := int(rules["limit"])
	var fitting: Array[String] = []
	for row in stock():
		var f: Dictionary = row["facts"]
		var bits := int(f.get("color", CardValue.COLORLESS))
		if bits != CardValue.COLORLESS and not CardValue.first_color(bits) in sold:
			continue
		if place % 2 == 1 and int(f.get("type", 0)) & CardValue.ARTIFACT != 0:
			continue
		if shop_rarity(f) > most:
			continue
		if int(held.get(String(row["name"]), 0)) >= limit:
			continue
		fitting.append(String(row["name"]))
	return fitting[dice.below(fitting.size())] if not fitting.is_empty() else ""


## A card's rarity as the shop reads it (`GetCardRarity`): power and
## restricted cards and the Astral cards special.
static func shop_rarity(f: Dictionary) -> int:
	if int(f.get("extra", 0)) & 0x180 != 0 or int(f.get("exp", 1)) == 0x40:
		return 4
	return int(f.get("rarity", 1))


## How many copies of a card the deck in use may hold
## (`GetRemainingAllowedCardCopies`).
static func copies_allowed(player: AdventurePlayer) -> int:
	var size := 0
	for card in player.cards:
		if _in_use(player, card as Dictionary):
			size += 1
	return allowed_for(player, size)


## How many copies of a card a deck of [param size] cards may hold: one
## under 40, two from 40, three from 60 — one more with Tome of
## Enlightenment.
static func allowed_for(player: AdventurePlayer, size: int) -> int:
	var limit := 1
	if size >= 40:
		limit = 2
	if size >= 60:
		limit = 3
	return limit + (1 if player.owns("Tome of Enlightenment") else 0)


## Copies of [param card_name] in the deck in use.
static func in_deck(player: AdventurePlayer, card_name: String) -> int:
	var count := 0
	for card in player.cards:
		var entry := card as Dictionary
		if String(entry.get("card", "")) == card_name and _in_use(player, entry):
			count += 1
	return count


## THE DECK IN USE, counted once: card name → copies — for a question asked
## of many cards ([method in_deck] walks the whole collection each time).
static func deck_counts(player: AdventurePlayer) -> Dictionary:
	var counts := {}
	for card in player.cards:
		var entry := card as Dictionary
		if _in_use(player, entry):
			var card_name := String(entry.get("card", ""))
			counts[card_name] = int(counts.get(card_name, 0)) + 1
	return counts


## Whether the hero's card [param entry] is in the deck in use.
static func _in_use(player: AdventurePlayer, entry: Dictionary) -> bool:
	return (entry.get("decks", []) as Array).has(player.current_deck)


## THE CARDS A SHOP MAY HOLD, read once, by name: `{name, facts}`. With the
## 1997 program imported ([method CardValue.original]) they are the cards
## its draw let through (`RunTownServicesMenu`, visitLocation.c 1810–1852):
## of the base set (`expansion` & 0xC1), neither made for ante nor kept from
## the program's card pickers (`extra_ability` 0x900), nor a power or
## restricted card (0x180) — Mishra's Factory and Strip Mine among them, and
## the Oasis, whose lack of any colour no town sells ([method _draw]).
## Without it: the base set's cards less every land, a dungeon's treasure, a
## banned or restricted card. The basic lands come by their own place only.
## Read again when the card pool changes ([method CardValue.pool_moved]).
static func stock() -> Array[Dictionary]:
	if CardValue.pool_moved(_read_at):
		forget()
	_read_at = CardRegistry.revision
	if not _stock.is_empty():
		return _stock
	CardRegistry.ensure_loaded()
	var treasures: Array[String] = []
	for row in ShandalarWorld.DUNGEON_CARDS:
		treasures.append(String(row[1]))
	var names: Array = CardRegistry.all_names()
	names.sort()
	for card_name in names:
		var name_text := String(card_name)
		if _stocked(name_text, treasures):
			_stock.append({"name": name_text, "facts": CardValue.facts(CardRegistry.get_card(name_text))})
	return _stock


## Whether [param card_name] may stand in a shop ([method stock]), told by
## the cheap marks before its facts are read: a card the 1997 program never
## had and of no base set — a pack's, thousands of them — is passed over
## before [method CardValue.derive] would read it off the card for nothing.
static func _stocked(card_name: String, treasures: Array[String]) -> bool:
	if card_name in LANDS or not CardRegistry.has_card(card_name):
		return false
	var own := CardValue.original(card_name)
	if not own.is_empty():
		return int(own.get("exp", 0)) & 0xC1 != 0 and int(own.get("extra", 0)) & 0x980 == 0
	if not CardValue.is_base(card_name) or card_name in treasures \
			or card_name in DeckFormat.BANNED or card_name in DeckFormat.RESTRICTED:
		return false
	return not CardRegistry.get_card(card_name).is_land()


## Forget the stock (a skin imported again, the card pool changed, a test).
static func forget() -> void:
	_stock.clear()
	_read_at = -1
