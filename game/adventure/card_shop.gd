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
##    up to four times `difficulty + 2` more), when a new card is drawn there;
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
##    a power card or a restricted one, a land other than a basic one;
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

## The cards a shop may hold, read once: `{name, facts}`.
static var _stock: Array[Dictionary] = []


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
## quest clock now stands: card names, "" for a place sold and not yet
## filled again.
static func offers(player: AdventurePlayer, slot: int) -> Array[String]:
	var shop := _shop(player, slot)
	var cards: Array = shop["cards"]
	var restock: Array = shop["restock"]
	var wanted := size_of(player, int(player.world.sites[slot]["type"]))
	while cards.size() < wanted:
		cards.append("")
		restock.append(-0x7fffffff)
	var wait := (clampi(player.difficulty, 0, 3) + 3) * 5
	var empty: Array[int] = []
	for i in cards.size():
		if String(cards[i]) == "" and player.quest_timer - int(restock[i]) >= wait:
			empty.append(i)
	if not empty.is_empty():
		var dice := MsvcRandom.new(player.dice)
		var land := dice.below(cards.size())
		for i in empty:
			cards[i] = _draw(player, slot, i, i == land, dice)
		player.dice = dice.state
	var out: Array[String] = []
	for card in cards:
		out.append(String(card))
	return out


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
	var shop := _shop(player, slot)
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


static func _shop(player: AdventurePlayer, slot: int) -> Dictionary:
	var key := str(slot)
	if not player.shops.has(key):
		player.shops[key] = {"cards": [], "restock": []}
	return player.shops[key]


## One card for place [param place] of site [param slot]: a basic land of a
## colour the town sells when [param land], else a card the rules allow.
static func _draw(player: AdventurePlayer, slot: int, place: int, land: bool, dice: MsvcRandom) -> String:
	var sold := colors_sold(player.world, slot)
	if land:
		var lands: Array[String] = []
		for i in COLOR_BITS.size():
			if COLOR_BITS[i] in sold:
				lands.append(LANDS[i])
		return lands[dice.below(lands.size())] if not lands.is_empty() else ""
	var most := place % 3 + 1
	var fitting: Array[String] = []
	var limit := copies_allowed(player)
	for row in stock():
		var f: Dictionary = row["facts"]
		var bits := int(f.get("color", CardValue.COLORLESS))
		if bits != CardValue.COLORLESS and not CardValue.first_color(bits) in sold:
			continue
		if place % 2 == 1 and int(f.get("type", 0)) & CardValue.ARTIFACT != 0:
			continue
		if shop_rarity(f) > most:
			continue
		if in_deck(player, String(row["name"])) >= limit:
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
		if ((card as Dictionary).get("decks", []) as Array).has(player.current_deck):
			size += 1
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
		if String(entry.get("card", "")) == card_name and (entry.get("decks", []) as Array).has(player.current_deck):
			count += 1
	return count


## THE CARDS A SHOP MAY HOLD, read once: the base set's, less every land
## (the basic lands come by their own place), a card made for ante, a
## dungeon's treasure, a power or restricted card ([CardValue.facts]: the
## 1997 program's flags when it was imported).
static func stock() -> Array[Dictionary]:
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
		var data := CardRegistry.get_card(name_text)
		if data == null or data.is_land():
			continue
		var f := CardValue.facts(data)
		if bool(f.get("derived", true)):
			if not CardValue.is_base(name_text) or name_text in treasures \
					or name_text in DeckFormat.BANNED or name_text in DeckFormat.RESTRICTED:
				continue
		else:
			if int(f.get("exp", 0)) & 0xC1 == 0 or int(f.get("extra", 0)) & 0x980 != 0:
				continue
		_stock.append({"name": name_text, "facts": f})
	return _stock


## Forget the stock (a skin imported again, packs changed, a test).
static func forget() -> void:
	_stock.clear()
