class_name SealedPool
extends RefCounted
## [QoL] THE SEALED DECK'S POOL — the cards a Sealed Deck tournament deals
## you, and the only cards the Inventory then offers. Everything the Deck
## Builder's dice medallion knows that is not a pixel.
##
## The 1997 shell offered the format by name; no program we hold
## contains its builder:
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
## `WinSealedTournament.avi` in the art — but no program we hold has the
## code behind any of it.
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
## pack shape: a BOOSTER is fifteen cards — one rare, three
## uncommons, one basic land, ten commons — and a STARTER (the 1997
## strings' word; the owner's "tournament pack") is sixty — three rares,
## nine uncommons, twenty-six commons and twenty-two basic lands. On top
## of the packs the player may ask for FREE LANDS (`@SHELLPAGE_SEALEDDECK`
## has the line; here it is N of EACH of the five types, so the mana base
## is never the reason a pool is unplayable) and, the owner's own addition,
## a handful of cards drawn from the whole library with no rarity at all.
##
## THE SHEETS use printed rarity from DeckStats.rarity_of, NOT the decorative
## L marker: legendary is a supertype, and uncommon legends belong in the
## uncommon sheet. The five ordinary basic lands have their own sheet;
## snow-covered basics use printed rarity (common), preserving recipe v1's
## fixed five-name land sheet. The game's canonical
## rarity per name is used across eligible sets, not factory/set-specific
## collation. A card the data cannot place is on no sheet.
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
##
## [QoL] COMMUNITY CARDS ([CommunityCards], the set
## [constant CommunityCard.SET_CODE]) sit on the sheets by their own card's
## rarity, a MYTHIC on the rare sheet. A COMMUNITY BOOSTER
## ([method community_booster]) is a booster of community cards alone, its
## basic land off the ordinary land sheet; a small set fills a short slot
## from other community cards and repeats a card only when the whole set
## is smaller than the pack.

## The owner's booster, slot by slot, in the order a pack is fanned.
const BOOSTER := {"rare": 1, "uncommon": 3, "land": 1, "common": 10}
## The owner's tournament pack — `@SEALEDDECK_FOILPACKSCREEN`'s "Starter".
const STARTER := {"rare": 3, "uncommon": 9, "common": 26, "land": 22}
## The order the slots are drawn and listed in: the way a pack is sorted
## when it is opened, rarest first, lands last.
const SLOT_ORDER: Array[String] = ["rare", "uncommon", "common", "land"]
## The five basic lands, in the deck builder's own colour order.
const LAND_NAMES: Array[String] = ["Plains", "Island", "Swamp", "Mountain", "Forest"]
## The rarities a community card is made at ([constant CommunityCard.RARITIES]),
## the sheets of a community booster, rarest first.
const COMMUNITY_TIERS: Array[String] = ["mythic", "rare", "uncommon", "common"]
## A community booster's rare slot holds a mythic about one time in this
## many, when the set has both.
const MYTHIC_ODDS := 8
## Where a community booster's short slot looks next: the next rarity down
## first, then up, so no card repeats while the set has one unused. A land
## slot with no basic land in the pool takes a community card.
const COMMUNITY_FALLBACK := {"rare": ["uncommon", "common"],
	"uncommon": ["common", "rare", "mythic"], "common": ["uncommon", "rare", "mythic"],
	"land": ["common", "uncommon", "rare", "mythic"]}

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
## Boosters of community cards only ([method community_booster]).
var community_boosters := 0
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
## Timed drafts carry a self-contained replay record. Legacy dice deals do not.
var draft_recipe: Dictionary = {}


## How many cards the settings deal — the number the window shows before
## the dice are thrown.
func card_total() -> int:
	return (boosters + community_boosters) * pack_size(BOOSTER) + starters * pack_size(STARTER) \
		+ free_lands * LAND_NAMES.size() + extras


static func pack_size(shape: Dictionary) -> int:
	var n := 0
	for slot in shape:
		n += int(shape[slot])
	return n


## The four sheets out of [param library] (an Array of [CardData]), keyed
## by [constant SLOT_ORDER]; sorted by name so a seed means the same pool
## whatever order the registry handed the cards over in. A name is placed
## once however often the library repeats it; the check is a set, not
## `Array.has` on a sheet of a thousand-odd commons (whole-game campaign
## 2026-10: the draft setup validates the pool on every keystroke).
static func sheets(library: Array) -> Dictionary:
	var out := {"rare": [], "uncommon": [], "common": [], "land": []}
	var placed := {}
	# The community names once, not a registry ask per card.
	var community := {}
	for card_name in CardRegistry.community_names():
		community[card_name] = true
	for data in library:
		if data == null or placed.has(data.card_name):
			continue
		placed[data.card_name] = true
		var tier := _printed_slot(data.card_name, community.has(data.card_name))
		if out.has(tier):
			out[tier].append(data.card_name)
	for slot in out:
		out[slot].sort()
	return out


## Open the packs. [param library] is the whole card pool, [param roll]
## the seed; the pool is the same for the same two. Clears the last deal.
func deal(library: Array, roll: int) -> void:
	draft_recipe = {}
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
	if community_boosters > 0:
		var library_names: Array = []
		for data in library:
			if data != null:
				library_names.append(data.card_name)
		var community := community_sheets(library_names)
		# No community card to deal: no community booster, and the count
		# says so, so [method card_total] is still what was dealt.
		if community_count(community) == 0:
			community_boosters = 0
		var pick := func(bound: int) -> int: return rng.randi_range(0, bound - 1)
		for i in community_boosters:
			_keep("Community Booster %d" % (i + 1), community_booster(community, sheet["land"], pick))
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
##
## The QUIET existence check, for the same reason [method
## DeckBuilderScreen._sealed_library] uses one: a pool dealt with a card
## pack enabled still names cards the registry drops the moment that pack
## goes off, and [method slot_counts] and the pack window's slot letters
## ask this for every dealt name. `get_card` is the loud fetch and printed
## one `CardRegistry: unknown card` per name (2026-09-17).
static func slot_of(card_name: String) -> String:
	if not CardRegistry.has_card(card_name):
		return ""
	var tier := _printed_slot(card_name, CardRegistry.has_community(card_name))
	return tier if SLOT_ORDER.has(tier) else ""


## The sheet [param card_name]'s printed rarity names, unchecked: a basic
## land's own; a COMMUNITY CARD's ([param community]) by its own card
## ([method community_rarity]), a mythic on the rare sheet — read before
## the game's rarity table, which may list a name a community card took;
## any other by [method DeckStats.rarity_of].
static func _printed_slot(card_name: String, community: bool) -> String:
	if LAND_NAMES.has(card_name):
		return "land"
	if community:
		var word := community_rarity(card_name)
		return "rare" if word == "mythic" else word
	return DeckStats.rarity_of(card_name)


# ----------------------------------------- [QoL] the community booster --

## A community card's printed rarity, one of [constant COMMUNITY_TIERS]
## (its card's own, recorded under [constant CommunityCard.SET_CODE];
## common when the record says nothing else).
static func community_rarity(card_name: String) -> String:
	var word := CardRegistry.rarity_of(card_name, CommunityCard.SET_CODE)
	return word if COMMUNITY_TIERS.has(word) else "common"


## The community cards among [param names], once each, by
## [constant COMMUNITY_TIERS] — each sheet sorted, so a seed means the same
## booster whatever order the names came in.
static func community_sheets(names: Array) -> Dictionary:
	var out := {}
	for tier in COMMUNITY_TIERS:
		out[tier] = []
	var placed := {}
	for value in names:
		var card_name := String(value)
		if placed.has(card_name) or LAND_NAMES.has(card_name) or not CardRegistry.has_community(card_name):
			continue
		placed[card_name] = true
		out[community_rarity(card_name)].append(card_name)
	for tier in out:
		out[tier].sort()
	return out


## Community cards on [param sheets] ([method community_sheets]), all sheets together.
static func community_count(sheets: Dictionary) -> int:
	var n := 0
	for tier in COMMUNITY_TIERS:
		n += (sheets.get(tier, []) as Array).size()
	return n


## ONE COMMUNITY BOOSTER: [constant BOOSTER]'s fifteen slots, every card a
## community card off [param sheets] ([method community_sheets]) but the
## basic land, which comes off [param lands] — the ordinary land sheet,
## with replacement as ever. [param pick] answers a whole number below the
## one it is given: the dealer's own randomness, so [DraftRecipe] replays a
## booster with its frozen counter words and [method deal] with its seed.
##
## THE RARE SLOT is a mythic about one time in [constant MYTHIC_ODDS] when
## the set has mythics and rares, and whichever it has otherwise.
## A SMALL SET is never refused. Every slot draws its own sheet first,
## without replacement; a slot left short then takes the next rarity down,
## then up ([constant COMMUNITY_FALLBACK]); and only once the whole set is
## used does a fresh copy of it come in, so a card repeats only when the
## set is smaller than the pack, and only after every card came once.
##
## FROZEN: a draft recipe replays this at every check, with its own frozen
## [param shape] ([constant DraftRecipe.BOOSTER]). A change to it, to
## [constant MYTHIC_ODDS] or to [constant COMMUNITY_FALLBACK] changes old
## pools, and needs a new [constant DraftRecipe.ALGORITHM].
static func community_booster(sheets: Dictionary, lands: Array, pick: Callable,
		shape: Dictionary = BOOSTER) -> Array[String]:
	var left := {}
	for tier in COMMUNITY_TIERS:
		left[tier] = (sheets.get(tier, []) as Array).duplicate()
	var whole := community_count(sheets)
	var top := "rare"
	if not left["mythic"].is_empty() and (left["rare"].is_empty() or int(pick.call(MYTHIC_ODDS)) == 0):
		top = "mythic"
	var own := {"rare": [top], "uncommon": ["uncommon"], "common": ["common"]}
	var drawn := {}
	for slot in SLOT_ORDER:
		drawn[slot] = []
	var rounds := 0
	while true:
		for slot in SLOT_ORDER:
			var want := int(shape[slot])
			if slot == "land":
				while drawn[slot].size() < want and not lands.is_empty():
					drawn[slot].append(String(lands[int(pick.call(lands.size()))]))
				continue
			for tier in own[slot]:
				_take(drawn[slot], left[tier], want - drawn[slot].size(), pick)
		var short := false
		for slot in SLOT_ORDER:
			for tier in COMMUNITY_FALLBACK[slot]:
				_take(drawn[slot], left[tier], int(shape[slot]) - drawn[slot].size(), pick)
			short = short or drawn[slot].size() < int(shape[slot])
		rounds += 1
		# Short after both passes means every sheet is used up: the set is
		# smaller than the pack, and a fresh copy of it fills the rest.
		if not short or whole == 0 or rounds > pack_size(shape):
			break
		for tier in COMMUNITY_TIERS:
			left[tier] = (sheets.get(tier, []) as Array).duplicate()
	var out: Array[String] = []
	for slot in SLOT_ORDER:
		var cards: Array[String] = []
		cards.assign(drawn[slot])
		cards.sort()
		out.append_array(cards)
	return out


## Up to [param count] names off [param sheet] into [param into], each
## taken out of [param sheet] — a uniform pick among what is left, and
## the last name moved into its place.
static func _take(into: Array, sheet: Array, count: int, pick: Callable) -> void:
	for _i in mini(count, sheet.size()):
		var j := int(pick.call(sheet.size()))
		into.append(String(sheet[j]))
		sheet[j] = sheet[sheet.size() - 1]
		sheet.pop_back()


## What a community booster makes do with, as the setup's summary says it
## — "" when every slot comes off its own sheet. [param lands] is how many
## basic lands the land sheet holds.
static func community_note(sheets: Dictionary, lands: int) -> String:
	var whole := community_count(sheets)
	if whole == 0:
		return ""
	var slots := pack_size(BOOSTER) - (int(BOOSTER["land"]) if lands > 0 else 0)
	if whole == 1:
		return "Community boosters: 1 community card for %d slots, so it repeats within a pack." % slots
	if whole < slots:
		return "Community boosters: %d community cards for %d slots, so some repeat within a pack." % [whole, slots]
	var short: Array[String] = []
	if (sheets.get("rare", []) as Array).size() + (sheets.get("mythic", []) as Array).size() < int(BOOSTER["rare"]):
		short.append("rare")
	for tier in ["uncommon", "common"]:
		if (sheets.get(tier, []) as Array).size() < int(BOOSTER[tier]):
			short.append(tier)
	var parts: Array[String] = []
	if not short.is_empty():
		var listed: String = short[-1] if short.size() == 1 \
			else "%s and %s" % [", ".join(short.slice(0, -1)), short[-1]]
		parts.append("too few %s cards, so other community cards fill those slots" % listed)
	if lands <= 0:
		parts.append("no basic land in Card pool, so a community card takes the land slot")
	return "" if parts.is_empty() else "Community boosters: %s." % "; ".join(parts)


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
