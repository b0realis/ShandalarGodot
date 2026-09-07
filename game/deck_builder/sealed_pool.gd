class_name SealedPool
extends RefCounted
## [QoL] THE SEALED DECK'S POOL — the cards a Sealed Deck tournament deals
## you, and the only cards the Inventory then offers. Everything the Deck
## Builder's dice medallion knows that is not a pixel.
##
## The 1997 shell offered the format by name and never shipped its
## builder:
##
## > *"Sealed Deck: Compete in the most popular form of Magic Tournament."*
## > — `@SHELLSCREEN_DUEL` (`MagicTG/Uistrings.txt`, the 1997 copy)
##
## and the string table has the whole screen roughed in
## (`@SHELLPAGE_SEALEDDECK`: *"Each player gets %d cards"*, *"Free
## lands:"*, *"Minimum deck size: 40 cards"*; `@SEALEDDECK_FOILPACKSCREEN`:
## *"Sealed Deck Tournament Information"*, *"%d Starter Packs"*, *"%d
## Booster Packs"*, *"Your Starters and Boosters"*, *"Selected Pack"*,
## *"Cards In Pack"*), with `GAMETYPE_SEALED_DECK = 3` in `defs.h` and a
## `WinSealedTournament.avi` in the art — but no code behind any of it.
## The 1998 strategy guide says what the format is in one sentence:
##
## > *"You take a Sealed Deck and a booster, and are supposed to make a
## > forty card deck out of it."*  (Sealed Deck Strategy, p.75)
##
## So this is the pack-opening half of that screen, built to the owner's
## brief (2026-09-07): *"make the most of the random selection and make
## yourself a min 40 card deck"*. The tournament ladder is not here.
##
## THE PACKS are the era's own shapes, given by the owner and matching the
## printed product: a BOOSTER is fifteen cards — one rare or legend, three
## uncommons, one basic land, ten commons — and a STARTER (the 1997
## strings' word; the owner's "tournament pack") is sixty — three rares,
## nine uncommons, twenty-six commons and twenty-two basic lands. On top
## of the packs the player may ask for FREE LANDS (`@SHELLPAGE_SEALEDDECK`
## has the line; here it is N of EACH of the five types, so the mana base
## is never the reason a pool is unplayable) and, the owner's own addition,
## a handful of cards drawn from the whole library with no rarity at all.
##
## THE SHEETS a slot draws from are the four rarity tiers the deck builder
## already letters cards with ([method DeckStats.rarity_tier]): the rare
## slot takes the R and L sheets together — *"1 rare or legendary"* is the
## brief, and it is also the printed fact, since the sixty-one legends were
## printed at rare and uncommon both and the tier says what a card IS —
## the uncommon slot the U sheet, the common slot the C sheet with the
## basic lands lifted out of it (they have their own slot), and the land
## slot the five basics. A card the data cannot place (a proxy, a printing
## outside the eight sets) is on no sheet.
##
## WITHIN ONE PACK a sheet is drawn without replacement — a booster does
## not hold two Craw Wurms — and across packs the sheets are whole again,
## so three boosters can. The basic-land slots draw WITH replacement, five
## names being the whole sheet. The deal is a function of [member seed]:
## the same seed over the same library is the same pool, which is what
## makes it testable and what would let a pool be handed to a second
## player one day.
##
## THIS IS NOT THE DECK. [member counts] is what you HOLD; the deck the
## builder makes from it is the [DeckModel] as ever, and the builder's
## screen is what refuses a fifth copy of a card the pool dealt four of.

## The owner's booster, slot by slot, in the order a pack is fanned.
const BOOSTER := {"rare": 1, "uncommon": 3, "land": 1, "common": 10}
## The owner's tournament pack — `@SEALEDDECK_FOILPACKSCREEN`'s "Starter".
const STARTER := {"rare": 3, "uncommon": 9, "common": 26, "land": 22}
## The order the slots are drawn and listed in: the way a pack is sorted
## when it is opened, rarest first, lands last.
const SLOT_ORDER: Array[String] = ["rare", "uncommon", "common", "land"]
## The five basic lands, in the deck builder's own colour order.
const LAND_NAMES: Array[String] = ["Plains", "Island", "Swamp", "Mountain", "Forest"]

## The owner's defaults: *"boosters … default 3"*, *"tournament packs …
## default 1"*, *"each land type (default 0)"*, *"totally random cards
## (default 0)"*. The 1997 screen's own arithmetic for its defaults —
## *"Each player gets %d cards"* — is [method card_total].
const DEFAULT_BOOSTERS := 3
const DEFAULT_STARTERS := 1
const DEFAULT_FREE_LANDS := 0
const DEFAULT_EXTRAS := 0
## Enough packs to hold a whole draft table's worth; the spinner's ceiling.
const MOST_PACKS := 12
const MOST_FREE_LANDS := 30
const MOST_EXTRAS := 60

var boosters := DEFAULT_BOOSTERS
var starters := DEFAULT_STARTERS
## Of EACH basic land type.
var free_lands := DEFAULT_FREE_LANDS
## Cards drawn from the whole library, any rarity.
var extras := DEFAULT_EXTRAS

## The roll the pool was dealt from; 0 until [method deal].
var seed := 0
## Every pack in the order it was opened: `{"title": String, "cards":
## Array[String]}`, the cards in [constant SLOT_ORDER] and by name within
## a slot — the "Selected Pack" list of the foil-pack screen.
var packs: Array[Dictionary] = []
## `name -> copies held`, over every pack — the master library.
var counts: Dictionary = {}


## How many cards the settings deal — the number the window shows before
## the dice are thrown.
func card_total() -> int:
	return boosters * pack_size(BOOSTER) + starters * pack_size(STARTER) \
		+ free_lands * LAND_NAMES.size() + extras


static func pack_size(shape: Dictionary) -> int:
	var n := 0
	for slot in shape:
		n += int(shape[slot])
	return n


## The four sheets out of [param library] (an Array of [CardData]), keyed
## by [constant SLOT_ORDER]; sorted by name so a seed means the same pool
## whatever order the registry handed the cards over in.
static func sheets(library: Array) -> Dictionary:
	var out := {"rare": [], "uncommon": [], "common": [], "land": []}
	for data in library:
		if data == null:
			continue
		if (data.supertypes & Mtg.Supertype.BASIC) != 0:
			out["land"].append(data.card_name)
			continue
		var tier := DeckStats.rarity_tier(data)
		if tier == "legendary":
			tier = "rare"
		if out.has(tier):
			out[tier].append(data.card_name)
	for slot in out:
		out[slot].sort()
	return out


## Open the packs. [param library] is the whole card pool, [param roll]
## the seed; the pool is the same for the same two. Clears the last deal.
func deal(library: Array, roll: int) -> void:
	seed = roll
	packs = []
	counts = {}
	var sheet := sheets(library)
	var rng := RandomNumberGenerator.new()
	rng.seed = roll
	# Starters first, as `@SEALEDDECK_FOILPACKSCREEN` lists them.
	for i in starters:
		_open("Starter Pack %d" % (i + 1), STARTER, sheet, rng)
	for i in boosters:
		_open("Booster Pack %d" % (i + 1), BOOSTER, sheet, rng)
	if free_lands > 0:
		var lands: Array[String] = []
		for land in LAND_NAMES:
			for _i in free_lands:
				lands.append(land)
		_keep("Free Lands", lands)
	if extras > 0:
		var everything: Array = []
		for slot in SLOT_ORDER:
			everything.append_array(sheet[slot])
		var drawn := _draw(rng, everything, extras)
		drawn.sort()
		_keep("Random Cards", drawn)


func _open(title: String, shape: Dictionary, sheet: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var cards: Array[String] = []
	for slot in SLOT_ORDER:
		var wanted := int(shape.get(slot, 0))
		if wanted <= 0:
			continue
		var drawn: Array[String] = []
		if slot == "land":
			var names: Array = sheet["land"]
			for _i in wanted:
				if not names.is_empty():
					drawn.append(String(names[rng.randi_range(0, names.size() - 1)]))
		else:
			drawn = _draw(rng, sheet[slot], wanted)
		drawn.sort()
		cards.append_array(drawn)
	_keep(title, cards)


## [param wanted] names off [param sheet] without replacement — a partial
## Fisher-Yates, so a pack of ten commons costs ten swaps and not a
## shuffle of the whole sheet. A sheet shorter than the ask gives all of
## itself and no more.
static func _draw(rng: RandomNumberGenerator, sheet: Array, wanted: int) -> Array[String]:
	var deck := sheet.duplicate()
	var out: Array[String] = []
	var take: int = mini(wanted, deck.size())
	for i in take:
		var j := rng.randi_range(i, deck.size() - 1)
		var swap: Variant = deck[i]
		deck[i] = deck[j]
		deck[j] = swap
		out.append(String(deck[i]))
	return out


func _keep(title: String, cards: Array[String]) -> void:
	packs.append({"title": title, "cards": cards})
	for card_name in cards:
		counts[card_name] = copies_of(card_name) + 1


## Copies of [param card_name] the pool dealt; 0 for a card it did not.
func copies_of(card_name: String) -> int:
	return int(counts.get(card_name, 0))


## Cards dealt, all packs together.
func total() -> int:
	var n := 0
	for card_name in counts:
		n += int(counts[card_name])
	return n


## How many of the dealt cards sit on each sheet, keyed by
## [constant SLOT_ORDER] — the tally line under the packs.
func slot_counts() -> Dictionary:
	var tally := {"rare": 0, "uncommon": 0, "common": 0, "land": 0}
	for card_name in counts:
		var slot := slot_of(card_name)
		if slot != "":
			tally[slot] += int(counts[card_name])
	return tally


## Which sheet a card is on, by name — `""` when it is on none.
static func slot_of(card_name: String) -> String:
	var data := CardRegistry.get_card(card_name)
	if data == null:
		return ""
	if (data.supertypes & Mtg.Supertype.BASIC) != 0:
		return "land"
	var tier := DeckStats.rarity_tier(data)
	return "rare" if tier == "legendary" else tier


## The tally in a sentence: "105 cards — 6 rare, 18 uncommon, 56 common,
## 25 land".
func summary() -> String:
	var tally := slot_counts()
	return "%d cards — %d rare, %d uncommon, %d common, %d land" % [total(),
		tally["rare"], tally["uncommon"], tally["common"], tally["land"]]


## Every name dealt, sorted.
func names() -> Array[String]:
	var out: Array[String] = []
	for card_name in counts:
		out.append(String(card_name))
	out.sort()
	return out
