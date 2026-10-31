class_name CardTrade
extends RefCounted
## TRADING FOR CARDS (the owner, 2026-10-23: *"Build all trade features"*)
## — 1.3's `BuyAnyCardFromTown` (00530b90), the one card browser behind
## three trades ([CardTradePane]):
##  - A TOWN'S TRADE (`BuyTownSpecialCardOffer`, 004f18c0). Every town and
##    city trades one kind of card, a colour's or a type's (its `trade`,
##    [WorldGenerator]: "Red cards", "Any creatures"), for amulets. On each
##    visit the town wants amulets of one colour of its land, drawn at
##    random (1997 drew 199 times and the last draw of a colour of the land
##    won: one draw among the land's colours; `RunTownServicesMenu`,
##    visitLocation.c 1672–1684). [1997 meant draws 0–80 to keep only
##    colours the hero holds an amulet of; with no stop the 118 late draws
##    always overwrite them, so the preference never took effect — kept as
##    played, the owner's I-1, docs/adventure-unused-1997-features.md.]
##    While the hero holds such an amulet, and the town has not traded for
##    more than (difficulty + 3) · 18 steps of the quest clock — counted
##    from its last trade, long ago before the first
##    (`special_card_restock_timer` −1000) —, "Trade red amulet for Any
##    creatures" stands where the wise man is. The screen closed, the wait
##    begins again, a card traded or not. Only the town's colour is taken.
##  - THE NOMAD'S BAZAAR, a lair ([LairEvent]): any card for gold — the 1997
##    price ([CardValue]) four times, half again or twice for a card of no
##    colour of the land the hero stands on, as in a town (half again for a
##    colourless card; a card of no colour at all, unchanged) ([method
##    CardValue.land_markup]), times 1250 over 750 and up to 96 more (a tenth
##    of the hero's place within the tile, one coordinate times the other),
##    down to a multiple of 5 between 5 and 1000, times the copies, and never
##    under 50 gold an amulet's worth. [Ours: 1997 read the land's colour
##    wrongly here, as a colour's number, so that on black land every
##    coloured card counted as of a colour that goes with it, and a
##    colourless card cost half again on blue and red land only.]
##  - THE DIAMOND MINE, a lair: any card for amulets of any colours, each
##    amulet taken from a colour drawn at random among those the hero holds.
##  - A CREATURE QUEST'S REWARD (part B, [constant REWARD]; `VisitTownSlot`,
##    visitLocation.c 4512–4545): back at the town or city that asked for
##    the creature, a card of what the town trades, FREE — "Which card do
##    you seek?", then "Will you take this card... Yes / No" — and one must
##    be taken (No goes back to the cards). One copy, a basic land too (1997
##    added the one card chosen), in no deck ([method
##    AdventurePlayer.add_card]: lost when the bag is full, as in 1997).
## The price is asked as the card is chosen ([method offer]) and the purse
## read again as the trade is made ([method pay]), as 1997 did: what was
## held then may be gone.
## A card costs its rarity in amulets — 1 common (2 for a common the program
## favoured, `extra_ability` 0x400), 2 uncommon, 3 rare, 4 special — and a
## basic land comes four at a time for one. The cards: every card of the
## adventure but the dungeons' treasures and those 1997 kept from its card
## pickers (`extra_ability` 0x900; without the 1997 program, the same marks
## by name, [method CardValue.derive]: a restricted card that is no
## treasure, and an ante card, is traded as 1997 traded it), by name; no
## copy limit (a card the deck in use could take no more of shows dimmed and
## may still be traded, as in 1997).

const TOWN := "town"
const BAZAAR := "bazaar"
const MINE := "mine"
const REWARD := "reward"
## `@VISIT` 25: the free pick's question.
const TAKE := "Will you take this card..."
## `@CITYCARDTEXT`: what a town trades, by colour (0 colourless … 5 white)
## and by type (1 land … 5 fast effects; 6 artifacts is never made).
const COLOR_WORDS: Array[String] = ["Colorless", "Black", "Blue", "Green", "Red", "White"]
const CLASS_WORDS: Array[String] = ["cards", "land", "creatures", "enchantments", "sorceries",
	"fast effects", "artifacts"]
## The card types each type of trade takes (1997 type bits).
const CLASS_TYPES: Array[int] = [0, CardValue.LAND, CardValue.CREATURE, CardValue.ENCHANTMENT,
	CardValue.SORCERY, CardValue.INSTANT | CardValue.INTERRUPT, CardValue.ARTIFACT]
## Basic lands come this many for one amulet (1997: a common among the first
## five cards).
const LAND_COPIES := 4
## The steps of the quest clock between two trades, per difficulty step
## (`(difficulty + 3) · 2 · 9`).
const TRADE_WAIT := 18
## Before the first trade: long ago (`special_card_restock_timer` −1000).
const NEVER := -1000
const AFFORD := "Hmmm... you can't afford this card yet."
const ASK := "Do you wish to trade?"

static var _catalogue: Array[Dictionary] = []
static var _all_catalogue: Array[Dictionary] = []
## The card pool's revision the catalogue was read against (−1: not yet).
static var _read_at := -1


# ------------------------------------------------------------ the cards --

## EVERY CARD A TRADE MAY OFFER, read once for the card pool as it stands
## (again when it changes, [method CardValue.pool_moved]): `{name, facts}`
## by name. [QoL] With all_cards, include the cards 1997 withheld; only
## paid traders opt in, through for_trader. Rewards keep the original pool.
static func catalogue(all_cards := false) -> Array[Dictionary]:
	if CardValue.pool_moved(_read_at):
		forget()
	_read_at = CardRegistry.revision
	var rows: Array[Dictionary] = _all_catalogue if all_cards else _catalogue
	if not rows.is_empty():
		return rows
	CardRegistry.ensure_loaded()
	for card_name in CardRegistry.all_names():
		var name_text := String(card_name)
		if not in_adventure(name_text):
			continue
		var f := CardValue.facts(CardRegistry.get_card(name_text))
		# 1997's marks, the table's or the derived facts' alike (part C stage
		# C3, h6-3; the owner, 2026-10-28): without the table the restricted
		# and banned lists kept out Channel, Fastbond and the ante cards,
		# which 1997 traded, and let in the 22 cards it kept back.
		if not all_cards and int(f.get("extra", 0)) & (CardValue.TREASURE | CardValue.KEPT_BACK) != 0:
			continue
		rows.append({"name": name_text, "facts": f})
	return rows


## The campaign's choice applies to town trades, the Bazaar and the Mine.
## The same pane's free quest reward keeps its original selection.
static func for_trader(player: AdventurePlayer, way: String) -> Array[Dictionary]:
	return catalogue(player != null and player.all_trader_cards and way in [TOWN, BAZAAR, MINE])


## Whether [param card_name] is one of the adventure's cards: the 1997
## game's base sets (Unlimited to Fourth Edition, the Astral cards), not a
## pack's — adventures are made without packs for now.
static func in_adventure(card_name: String) -> bool:
	var data := CardRegistry.get_card(card_name) if CardRegistry.has_card(card_name) else null
	return data != null and data.set_code in CardRegistry.SET_ORDER \
		and not CardRegistry.is_completion_card(card_name)


## Forget the cards (a skin imported again, the card pool changed, a test).
static func forget() -> void:
	_catalogue.clear()
	_all_catalogue.clear()
	_read_at = -1


## What a town of trade [param trade] takes (`GetTownCardDescription`):
## "Red cards", "Any creatures".
static func wares(trade: int) -> String:
	if trade & 0xFF != 0:
		for i in COLOR_WORDS.size():
			if trade & (1 << i) != 0:
				return COLOR_WORDS[i] + " cards"
	var kind := clampi(trade >> 8, 0, CLASS_WORDS.size() - 1)
	return "Any " + CLASS_WORDS[kind]


## Whether a card of facts [param f] is one a town of trade [param trade]
## takes: of its colour (a colourless card the colourless one), or of its
## type (an instant's trade takes interrupts too).
static func wanted(trade: int, f: Dictionary) -> bool:
	if trade & 0xFF != 0:
		return int(f.get("color", CardValue.COLORLESS)) & trade != 0
	var kind := trade >> 8
	if kind <= 0 or kind >= CLASS_TYPES.size():
		return true
	return int(f.get("type", 0)) & CLASS_TYPES[kind] != 0


## A card's price in amulets (`GetCardRarity`, and a favoured common one more).
static func amulets_for(f: Dictionary) -> int:
	var rank := CardShop.shop_rarity(f)
	if rank == 1 and int(f.get("extra", 0)) & CardValue.FAVOURED != 0:
		return 2
	return rank


## How many copies one trade gives: four basic lands, else one.
static func copies(card_name: String) -> int:
	return LAND_COPIES if card_name in CardShop.LANDS else 1


## THE NOMAD'S PRICE for [param data], the hero where they stand: with the
## dice's draw of [param draw] (0 to the hero's place's tenth − 1).
static func bazaar_price(player: AdventurePlayer, data: CardData, draw: int) -> int:
	var f := CardValue.facts(data)
	var value := CardValue.price_of(f) * 4
	var color := int(f.get("color", CardValue.COLORLESS))
	var here := player.tile()
	var tile_bits := ShandalarWorld.magic_mask(player.world.terrain(here.x, here.y))
	# The town's rule, but for a card of no colour at all, which the Nomad
	# leaves as it is (`… && color != 0`, visitLocation.c 4054).
	if color != 0:
		value = CardValue.land_markup(value, color, tile_bits)
	value = value * 1250 / (750 + draw)
	value = clampi(value / 50 * 5, 5, 1000) * copies(data.card_name)
	return maxi(value, amulets_for(f) * 50)


## How far the Nomad's dice reach at the hero's place: a tenth of the
## place within the tile, one coordinate times the other.
static func bazaar_reach(player: AdventurePlayer) -> int:
	return (player.position.y & 31) * (player.position.x & 31) / 10


# ------------------------------------------------------- a town's trade --

## THE HERO ARRIVES at town [param slot]: which colour of amulet it wants
## this visit, drawn among its land's colours ([method town_offer]).
static func arrive(player: AdventurePlayer, slot: int) -> void:
	var shop := CardShop.town_record(player, slot)
	var mask := CardShop.town_colors(player.world, slot)
	var hues: Array[String] = []
	for i in CardShop.COLOR_BITS.size():
		if mask & CardShop.COLOR_BITS[i] != 0:
			hues.append(AdventurePlayer.COLORS[i])
	if hues.is_empty():
		shop.erase("want")
		return
	var dice := MsvcRandom.new(player.dice)
	shop["want"] = hues[dice.below(hues.size())]
	player.dice = dice.state


## The colour town [param slot] favours this visit — 1997's
## `g_town_preferred_magic_color`, which its trade, its quest and its wise
## man all read: 1 black … 5 white, 0 when none was drawn.
static func favoured(player: AdventurePlayer, slot: int) -> int:
	var color := String((player.shops.get(str(slot), {}) as Dictionary).get("want", ""))
	return AdventurePlayer.COLORS.find(color) + 1


## WHAT TOWN [param slot] OFFERS TO TRADE this visit: `{color, trade,
## words}` — the amulet's colour, the town's trade and the button's words —
## or `{}` when it does not (a village, no such amulet, too soon).
static func town_offer(player: AdventurePlayer, slot: int) -> Dictionary:
	var site: Dictionary = player.world.sites[slot]
	if int(site["type"]) < 2 or int(site["type"]) > 3:
		return {}
	var trade := int(site.get("trade", 0))
	var shop := CardShop.town_record(player, slot)
	var color := String(shop.get("want", ""))
	if trade == 0 or color == "" or int(player.amulets.get(color, 0)) <= 0:
		return {}
	var wait := (clampi(player.difficulty, 0, 3) + 3) * TRADE_WAIT
	if player.quest_timer - int(shop.get("traded", NEVER)) <= wait:
		return {}
	return {"color": color, "trade": trade,
		"words": "Trade %s amulet for %s" % [color, wares(trade)]}


## The town's trade screen is closed: the wait begins again.
static func traded(player: AdventurePlayer, slot: int) -> void:
	CardShop.town_record(player, slot)["traded"] = player.quest_timer


# ------------------------------------------------------------ the trade --

## WHAT THE TRADER ASKS for [param card_name] in a trade of [param way]
## ([constant TOWN], [constant BAZAAR], [constant MINE]; [param color] the
## town's amulets, [param price] the Nomad's gold): `{copies, amulets, gold,
## words, afford}` — "I'll trade you 1 Serra Angel for 3 white amulets."
static func offer(player: AdventurePlayer, card_name: String, way: String, color := "",
		price := 0) -> Dictionary:
	var data := CardRegistry.get_card(card_name)
	var f := CardValue.facts(data)
	var count := copies(card_name)
	var out := {"copies": count, "amulets": 0, "gold": 0, "card": card_name}
	if way == REWARD:
		out["copies"] = 1
		out["afford"] = true
		out["words"] = "%s. %s" % [card_name, TAKE]
		return out
	var paid := ""
	if way == BAZAAR:
		out["gold"] = price
		paid = "%d gold pieces" % price
	else:
		var need := amulets_for(f)
		out["amulets"] = need
		var word := (color + " amulet") if way == TOWN else "amulet"
		paid = "%d %s%s" % [need, word, "" if need == 1 else "s"]
	out["afford"] = affords(player, out, way, color)
	out["words"] = "I'll trade you %d %s for %s." % [count, card_name, paid]
	return out


## Whether the hero holds now what [param asked] ([method offer]) wants by
## [param way]: its gold, that many amulets of the town's [param color], or
## that many amulets of any colours.
static func affords(player: AdventurePlayer, asked: Dictionary, way: String, color := "") -> bool:
	match way:
		BAZAAR:
			return player.gold >= int(asked.get("gold", 0))
		TOWN:
			return int(player.amulets.get(color, 0)) >= int(asked.get("amulets", 0))
		REWARD:
			return true
	return _amulets_held(player) >= int(asked.get("amulets", 0))


## The amulets the hero holds, of the five colours.
static func _amulets_held(player: AdventurePlayer) -> int:
	var count := 0
	for hue in AdventurePlayer.COLORS:
		count += maxi(int(player.amulets.get(hue, 0)), 0)
	return count


## THE TRADE MADE: what [param asked] ([method offer]) is paid — the town's
## colour of amulets, any amulets drawn at random, or the gold — and the
## card is the hero's, in no deck. `{traded, said}`. The purse is read
## again here, not taken from [param asked]'s `afford`, as 1997 read it
## again before taking (`BuyAnyCardFromTown`, visitLocation.c 4123–4145):
## what the hero held as the card was chosen may be gone (a World Magic
## cast while the trader waited) — then no trade, never a purse below
## nothing nor a card underpaid.
static func pay(player: AdventurePlayer, asked: Dictionary, way: String, color := "") -> Dictionary:
	if way == REWARD:
		return _take_reward(player, String(asked.get("card", "")))
	if not affords(player, asked, way, color):
		return {"traded": false, "said": AFFORD}
	# Through the bag ([method AdventurePlayer.add_card]; the bug pass of
	# part B, q4-3). [Ours: a full bag refuses the trade before it is paid.]
	if player.bag_room() < int(asked["copies"]):
		return {"traded": false, "said": AdventurePlayer.BAG_FULL}
	match way:
		BAZAAR:
			player.gold -= int(asked["gold"])
		TOWN:
			player.amulets[color] = int(player.amulets.get(color, 0)) - int(asked["amulets"])
		_:
			# Each amulet from a colour drawn among those held: enough are
			# held ([method affords]), so there is always one to draw.
			var dice := MsvcRandom.new(player.dice)
			for i in int(asked["amulets"]):
				var held: Array[String] = []
				for hue in AdventurePlayer.COLORS:
					if int(player.amulets.get(hue, 0)) > 0:
						held.append(hue)
				var hue := held[dice.below(held.size())]
				player.amulets[hue] = int(player.amulets[hue]) - 1
			player.dice = dice.state
	var card_name := String(asked["card"])
	for i in int(asked["copies"]):
		player.add_card(card_name)
	var count := int(asked["copies"])
	return {"traded": true, "said": "%s: %d more for your cards." % [card_name, count] if count > 1
		else "%s joins your cards." % card_name}


## THE QUEST'S REWARD TAKEN: card [param card_name], free, joins the hero's
## cards in no deck ([method AdventurePlayer.add_card]) — lost when the bag
## is full, as 1997's `AddCardToDeckSorted` lost it. `{traded, said}`:
## traded true either way (the reward is spent).
static func _take_reward(player: AdventurePlayer, card_name: String) -> Dictionary:
	if card_name == "":
		return {"traded": false, "said": ""}
	if player.add_card(card_name):
		return {"traded": true, "said": "%s joins your cards." % card_name}
	return {"traded": true, "said": "Your cards are too many: %s is lost." % card_name}
