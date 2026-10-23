class_name WorldMagicShop
extends RefCounted
## BUYING A WORLD MAGIC (the owner, 2026-10-23: part A of the world's
## missing pieces) — 1.3's `VisitTownSlot` (visitLocation.c 4604–4726):
##
##  - WHEN: on leaving a town or city (never a village, a castle, or a town
##    a wizard holds), every time, as long as a World Magic is not owned.
##  - WHICH: the unowned World Magic whose seller is nearest the town
##    (1997's distance, twice the larger axis plus the smaller, in tiles;
##    the lower number wins a tie). Each town or city sells at most one
##    ([member ShandalarWorld.world_magic_sites]; 0 for none or bought).
##  - THE SELLER ELSEWHERE: an advert — "WORLDMAGIC: Quickening costs 200
##    gold pieces." and its words, then "Travel North to Kraag Temple."
##  - THE SELLER HERE: "To release the WORLDMAGIC spell 'Quickening' from
##    Kraag Temple, you must pay 200 gold pieces." — " Never mind" or
##    " Pay the gold."; short of gold, "Insufficient Funds".
##  - THE PRICE is half the number in the 1997 table (`Scards`, 1.3
##    `global_state.h` 1225; the screen and the purse both use the half):
##    [constant PRICES]. No difficulty or Haggler's Coin changes it.
##  - BOUGHT: the World Magic is the hero's, its seller is cleared (1997
##    tested Haggler's Coin, the Fruit and the Ring by that), and the
##    journal says "Bought WM: %s".
## The pane is [WorldMagicPane]; the world screen asks [method offer] as
## the hero leaves a town.

## What each World Magic costs, in [constant AdventurePlayer.WORLD_MAGICS]'
## order: Sleight of Hand … Ring of the Guardian.
const PRICES: Array[int] = [400, 500, 350, 100, 400, 750, 200, 250, 300, 150, 300, 600]
## `@VISIT` 29–34.
const HEADING := "WORLDMAGIC:"
const COSTS := "costs %d gold pieces."
const TRAVEL := "Travel %s to %s."
const RELEASE := "To release the WORLDMAGIC spell '%s' from %s, you must pay %d gold pieces."
const NEVER_MIND := "Never mind"
const PAY := "Pay the gold."
const INSUFFICIENT := "Insufficient Funds"


## The price of World Magic [param index] (0–11).
static func price(index: int) -> int:
	return PRICES[index] if index >= 0 and index < PRICES.size() else 0


## The site slot that sells World Magic [param index], 0 for none (never
## placed, or bought). 0 is also a site slot, so a screen asking "what does
## site N sell" goes through [method sold_at], never `seller(…) == N`.
static func seller(world: ShandalarWorld, index: int) -> int:
	if world == null or index < 0 or index >= world.world_magic_sites.size():
		return 0
	return world.world_magic_sites[index]


## THE WORLD MAGIC SITE [param slot] SELLS: its index in
## [constant AdventurePlayer.WORLD_MAGICS], or -1 for none. Slot 0 sells
## nothing: [member ShandalarWorld.world_magic_sites] writes "sold nowhere"
## as 0, so a seller of 0 is never site 0 — 1997 guarded both of its screens
## with `town_index != 0` (1.3 `DrawCityInfoTownRow`, cityInfoScreen.c 756;
## `ShowWorldMapScreen`, mapScreen.c 736), and the generator never lets slot
## 0 sell ([WorldGenerator], its `slot != 0` test). Each town sells one at
## most; the first is the one.
static func sold_at(world: ShandalarWorld, slot: int) -> int:
	if world == null or slot <= 0:
		return -1
	return world.world_magic_sites.find(slot)


## Whether leaving site [param slot] brings the World Magic seller's offer:
## a town or a city no wizard holds.
static func asks_at(world: ShandalarWorld, slot: int) -> bool:
	return TownStatus.is_town(world, slot) and not TownStatus.ruled(world, slot)


## THE OFFER ON LEAVING site [param slot]: `{index, name, price, seller,
## seller_name, here, direction, afford}` — the nearest unowned World
## Magic, whether it is sold here, which way its seller lies and whether
## the purse can pay — or `{}` when there is none to offer.
static func offer(player: AdventurePlayer, slot: int) -> Dictionary:
	var world := player.world
	if not asks_at(world, slot):
		return {}
	var here := Vector2i(int(world.sites[slot]["x"]), int(world.sites[slot]["y"]))
	var best := -1
	var best_distance := 999
	for index in AdventurePlayer.WORLD_MAGICS.size():
		var sold_at := seller(world, index)
		if sold_at <= 0 or player.owns(AdventurePlayer.WORLD_MAGICS[index]):
			continue
		var there := Vector2i(int(world.sites[sold_at]["x"]), int(world.sites[sold_at]["y"]))
		var distance := WorldGenerator.distance(here.x - there.x, here.y - there.y)
		if distance < best_distance:
			best = index
			best_distance = distance
	if best < 0:
		return {}
	var sold_by := seller(world, best)
	var where := Vector2i(int(world.sites[sold_by]["x"]), int(world.sites[sold_by]["y"]))
	return {"index": best, "name": AdventurePlayer.WORLD_MAGICS[best], "price": price(best),
		"seller": sold_by, "seller_name": WorldNames.site_name(world, sold_by),
		"here": sold_by == slot, "direction": WorldNames.direction(player.tile(), where),
		"afford": player.gold >= price(best)}


## The advert's or the offer's words, a line each ([param offer] as
## [method offer] gives it).
static func words(offer: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	if not bool(offer.get("here", false)):
		lines.append(TRAVEL % [String(offer["direction"]), String(offer["seller_name"])])
	elif bool(offer.get("afford", false)):
		lines.append(RELEASE % [String(offer["name"]), String(offer["seller_name"]), int(offer["price"])])
	else:
		lines.append(INSUFFICIENT)
	return lines


## BUY the World Magic of [param offer] — the seller's own town, the gold
## at hand. The words for the screen, "" when it could not be bought.
static func buy(player: AdventurePlayer, offer: Dictionary) -> String:
	var index := int(offer.get("index", -1))
	if not bool(offer.get("here", false)) or index < 0 or index >= PRICES.size():
		return ""
	var magic: String = AdventurePlayer.WORLD_MAGICS[index]
	if player.owns(magic) or player.gold < price(index):
		return ""
	player.gold -= price(index)
	player.world_magics.append(magic)
	player.world.world_magic_sites[index] = 0
	player.log_event("magic", "Bought WM: %s" % magic)
	return "%s is yours." % magic
