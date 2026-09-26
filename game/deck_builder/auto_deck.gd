class_name AutoDeck
extends RefCounted
## [QoL] AUTODECK'S HEAD: a card pool and a handful of wishes
## in, a playable deck out. The 1997 program had nothing like it — its
## computer opponents played decks a designer had typed in — and the
## deck-lotus tool the owner pointed at (2026-09-18) turns out to have
## no automatic builder either, only a list parser and a stats view, so
## the method here is our own and it is written down so it can be argued
## with:
##
## 1. SCORE every card in the pool on its own ([method score]): a creature
##    by its body per mana — power before toughness — with the duel AI's
##    own keyword prices ([constant Evaluator.KEYWORD_VALUE]) and a
##    little for each ability, less its drawbacks ([method _drawbacks]:
##    an upkeep, a creature that enters asking for another, a coin flip)
##    and less again when its mana value is one a game rarely reaches; a
##    spell by the roles the duel AI reads off it
##    ([method AiDeckStudy.classify] — removal, burn, counters, card draw
##    and the rest), cheaper being better at the mana it is CAST for
##    ([method cast_value]: an X spell is no one-drop) and the lean
##    weighing the roles ([constant LEAN_ROLE_SCALE]: a deck of
##    creatures wants its pump and not a sweeper); a narrow answer
##    (colour hate, a Circle of Protection) is marked down, since the
##    deck is built blind to its opponent, and so is a spell that asks
##    for a Goblin to be sacrificed ([method _sacrifice_cost]). The SPEED then prices the mana value ([method worth],
##    [constant TEMPO]): a fast deck prizes what it can cast on the first
##    turn and discounts what it cannot cast before the fourth, a slow
##    deck the other way round.
## 2. CHOOSE THE COLOURS ([method _choose_colors]): every colour set the
##    wishes allow — up to five colours — is rated by the sum of its best
##    castable cards on the mana the set would be laid ([method
##    _mask_worth], [method _mana_expected]: each card less the strain
##    its pips put on that mana), one per cent off for every extra
##    colour, and the best one wins; the colours asked for are always in
##    it. A colour the fill then takes fewer than [constant SPLASH_CARDS]
##    cards of leaves the deck again with its cards ([method
##    _drop_splashes]) — the lands could not carry it — unless it was
##    asked for, kept, or a gold deck's second. A GOLD deck ([member
##    gold]) adds [constant GOLD_BONUS] to every multicoloured card's
##    worth, so the colours with the gold cards win and the fill reaches
##    for them.
## 3. FILL THE SPELLS ([method _fill_spells]) greedily, one card at a
##    time: the best worth after two firm nudges — towards the speed's
##    mana curve ([constant CURVES]: a fast deck is three parts in ten
##    first-turn castables, a slow deck one part in twenty-five) and
##    towards the creature share asked for — and a growing reluctance to
##    take a third and fourth copy of the same card. The four-of rule is
##    [method DeckModel.duplicates_allowed]'s, restricted cards are one
##    copy and banned cards never come under tournament rules. The
##    RARITY wish ([member rarity]) is a floor and a ceiling on the pool:
##    commons only, no rares, uncommons and up, rares and legends only.
##    THE POWER NINE ([member power_nine], [constant POWER_NINE]) are a
##    switch of their own, off by default: off, the builder avoids all
##    nine; on, it places them ahead of the fill ([method _place_power])
##    — the Lotus and the five Moxen in every deck, the three blue cards
##    in a blue deck — as far as the pool, the rarity wish and the
##    tournament rules' one copy allow.
## 4. LAY THE LANDS ([method _lay_lands]): the speed's count first
##    ([constant LANDS]), then settled by the curve the fill actually
##    made ([method lands_for]): Karsten's fit over 95,000 tournament
##    decks (2022) — 19.59 + 1.90 x the average mana value, less 0.28 a
##    cheap mana or draw spell — for 60 cards, two thirds of it for 40,
##    within [constant LAND_PLAY] of the speed's count. CLASSIC lands are
##    the five basics alone, split by what the spells need to be cast on
##    time ([method sources_for], Karsten's source counts: a one-pip card
##    wants about half the lands its colour, a two-pip card of two mana
##    wants nearly all of them) weighted by the demand; NON-CLASSIC lands
##    take the pool's dual lands, City of Brass and lands with abilities
##    first, best first ([method land_worth]), up to half the lands, and
##    the basics fill the rest. Basic lands are never scarce.
##
## The fill also knows what the mana base will bear ([method
## _source_strain]): a card whose pips want more sources of a colour than
## the deck's lands will give — a double pip of the second colour, most
## of a third colour — is marked down by every source it is short, so a
## two-colour deck reaches for single pips and a mono deck minds nothing.
##
## VARIETY ([member variety]) is the one wish that is not a wish about
## the deck: at 0 the builder takes the best card every time and the
## same pool and wishes build one deck under every seed but for a hair;
## above it, the seed rolls a taste for every name in the pool ([constant
## TASTE_SPAN], scaled by the variety) that moves the card's worth in
## the colour choice and the fill, so different seeds build genuinely
## different decks and the Deck Lab has a field to compare rather than
## one deck forty times.
##
## Nothing here consults an opponent or a game: the same pool, wishes
## and [member seed] build the same deck, which is what makes it a
## thing a test can hold still.

## The two deck sizes on offer — the 1997 floor and the tournament norm.
const SIZES: Array[int] = [40, 60]
## The creature share of the non-land cards, by the lean asked for.
const LEAN_CREATURES := "creatures"
const LEAN_BALANCED := "balanced"
const LEAN_SPELLS := "spells"
const LEANS: Array[String] = [LEAN_CREATURES, LEAN_BALANCED, LEAN_SPELLS]
const CREATURE_SHARE := {LEAN_CREATURES: 0.70, LEAN_BALANCED: 0.55, LEAN_SPELLS: 0.38}
## The speeds, and what each means in lands and in the curve.
const SPEED_FAST := "fast"
const SPEED_MEDIUM := "medium"
const SPEED_SLOW := "slow"
const SPEEDS: Array[String] = [SPEED_FAST, SPEED_MEDIUM, SPEED_SLOW]
## Lands by size and speed. The shipped decks run 34-37% land; a fast
## deck of one-drops wants a little less, a deck of six-drops a little
## more.
const LANDS := {
	40: {SPEED_FAST: 15, SPEED_MEDIUM: 16, SPEED_SLOW: 17},
	60: {SPEED_FAST: 22, SPEED_MEDIUM: 24, SPEED_SLOW: 25},
}
## How far the curve may move the land count from the speed's ([method
## lands_for]): Karsten's fit gives a deck of one-drops 21 lands and a
## deck of five-drops 27, and the speed's count is the middle of the
## band it may settle in.
const LAND_PLAY := 2
## Karsten's fit for the lands of a 60-card deck (2022; 95,143
## tournament decks): 19.59 + [constant LAND_PER_MANA] x the average
## mana value of the spells, less [constant LAND_PER_CHEAP] for every
## cheap mana or card-draw spell. A 40-card deck takes two thirds.
const LAND_BASE := 19.59
const LAND_PER_MANA := 1.90
const LAND_PER_CHEAP := 0.28
## Karsten's source counts (2022): the lands of a colour a 60-card deck
## wants to cast a card of that colour on time, nine games in ten, by
## the card's pips of the colour and its mana value (1, 2, 3, 4, 5 or
## more); a 40-card deck's counts below them. A card of more than three
## pips wants one more source a pip.
const SOURCES := {
	60: {1: [14, 13, 12, 11, 9], 2: [20, 20, 18, 16, 15], 3: [23, 23, 23, 20, 19]},
	40: {1: [10, 9, 8, 7, 7], 2: [14, 14, 13, 11, 11], 3: [16, 16, 16, 14, 14]},
}
## What every source a card is short costs it in the fill ([method
## _source_strain]): a double pip of two mana in an even two-colour
## deck, eight sources short of its twenty, loses about what a fair
## card scores over a poor one.
const SOURCE_STRAIN := 0.08
## The fewest cards of a colour the builder's own second (or third)
## colour is kept for ([method _drop_splashes]): under this the colour
## is a splash on two or three lands, and the deck is better without.
const SPLASH_CARDS := {60: 4, 40: 3}
## What an X in a cost counts for on the curve ([method cast_value]):
## a Fireball for two is the three-mana spell it is cast as.
const X_AS := 2
## The share of the spells at each mana value — 1 (and 0), 2, 3, 4 and 5
## or more — the fill holds to, by speed. The first bucket is the
## first-turn castables: a fast deck is three parts in ten of them and
## averages about 2.3 mana a spell, a slow deck one part in twenty-five
## and averages about 3.6.
const CURVES := {
	SPEED_FAST: [0.30, 0.34, 0.22, 0.10, 0.04],
	SPEED_MEDIUM: [0.12, 0.28, 0.28, 0.18, 0.14],
	SPEED_SLOW: [0.04, 0.18, 0.28, 0.26, 0.24],
}
## What the speed makes of a mana value: a factor on the score by curve
## bucket ([method worth]). A fast deck prizes its one-drops a fifth
## over and takes a five-drop at seven tenths; a slow deck the other
## way round, less sharply, since it still wants a two-drop or two;
## medium takes every card at its score.
const TEMPO := {
	SPEED_FAST: [1.2, 1.1, 1.0, 0.85, 0.7],
	SPEED_MEDIUM: [1.0, 1.0, 1.0, 1.0, 1.0],
	SPEED_SLOW: [0.8, 0.9, 1.0, 1.1, 1.15],
}
## The firm nudges of the fill: a bucket of the curve, or the creature
## share, a whole share over or under the wish moves a card's value by
## [constant NUDGE], capped at [constant NUDGE_CAP] — about what a good
## card scores, so what was asked for is met unless the pool has only
## junk left where it wants more.
const NUDGE := 3.0
const NUDGE_CAP := 2.5
## The rarity wishes — each a floor and a ceiling on [constant
## RARITY_RANK] ([constant RARITY_RANGE]): any card; commons only, the
## pauper deck; commons and uncommons, no rares and no legends;
## uncommons and up; rares and legends only. A card the game has no
## rarity for ranks as a common.
const RARITY_ANY := ""
const RARITY_PAUPER := "common"
const RARITY_NO_RARES := "uncommon"
const RARITY_UNCOMMON_UP := "uncommon_up"
const RARITY_RARES := "rares"
const RARITIES: Array[String] = [RARITY_ANY, RARITY_PAUPER, RARITY_NO_RARES,
	RARITY_UNCOMMON_UP, RARITY_RARES]
const RARITY_RANK := {"common": 0, "uncommon": 1, "rare": 2, "legendary": 3}
const RARITY_RANGE := {RARITY_ANY: [0, 3], RARITY_PAUPER: [0, 0], RARITY_NO_RARES: [0, 1],
	RARITY_UNCOMMON_UP: [1, 3], RARITY_RARES: [2, 3]}
## What a gold deck adds to a multicoloured card's worth ([method
## worth]) — a whole curve nudge ([constant NUDGE_CAP]), most of what a
## good card scores, so a fair gold card beats a good plain one and the
## gold cards fill their part of the curve before the plain ones get a
## look in. (A point and a half left a blue-black deck of the library
## five gold cards in thirty-six.)
const GOLD_BONUS := 2.5
## The Power Nine — the nine cards of Alpha every Vintage deck wants:
## Black Lotus and the five Moxen for mana on the first turn, whatever
## the deck's colours, and the three blue cards that draw three, take a
## turn and reshuffle the game. A switch of their own ([member
## power_nine]): off, the builder avoids all nine; on, it places them
## ahead of the fill ([method _place_power]) and [constant POWER_BONUS]
## goes on their worth, so the colour choice counts the blue three in a
## blue deck's favour and a build without the tournament rules reaches
## for the further copies.
const POWER_NINE: Array[String] = ["Black Lotus", "Mox Pearl", "Mox Sapphire", "Mox Jet",
	"Mox Ruby", "Mox Emerald", "Ancestral Recall", "Time Walk", "Timetwister"]
const POWER_BONUS := 2.5
## The five basic lands and the colour each makes.
const BASICS := {"Plains": Mtg.ManaColor.W, "Island": Mtg.ManaColor.U,
	"Swamp": Mtg.ManaColor.B, "Mountain": Mtg.ManaColor.R, "Forest": Mtg.ManaColor.G}
## The two mana bases: the classic five basics alone, or the pool's
## non-basic lands preferred ([method _lay_nonbasics]).
const LANDS_CLASSIC := "classic"
const LANDS_NONCLASSIC := "nonclassic"
const LAND_KINDS: Array[String] = [LANDS_CLASSIC, LANDS_NONCLASSIC]
## Copies of one non-basic land, and the share of the lands they may be
## in a non-classic deck.
const NONBASIC_CAP := 4
const NONBASIC_SHARE := 0.5
## Of those, the lands that make no colour of the deck (Mishra's
## Factory, Strip Mine) at most this many by deck size, and the lands
## that make no mana at all (Maze of Ith) at most this many of them, so
## the basics still carry the colours.
const COLORLESS_ROOM := {40: 2, 60: 4}
const NO_MANA_ROOM := {40: 1, 60: 2}
## What a basic land is worth ([method land_worth]): a non-basic must be
## worth more than that to take a basic's slot, so a Tundra in a
## blue-black deck — an Island with a white side — and City of Brass in
## one colour — an Island that hurts — stay in the pool.
const LAND_FLOOR := 1.0
## What the reader cannot price in a land ([method land_worth]): a land
## that is a creature, a card a turn, a land killed a turn, the Maze —
## and the path that hurts its owner more than anyone.
const LAND_NOTES := {"Mishra's Factory": 0.4, "Library of Alexandria": 0.6,
	"Strip Mine": 0.6, "Maze of Ith": 1.2, "Bazaar of Baghdad": 0.6, "Sorrow's Path": -1.0}
## A legend is one in play at a time; two in the deck is plenty.
const LEGEND_CAP := 2
## The reluctance to take another copy of the same card: nothing for the
## first, and more each time. A fast deck wants its best cards every
## game, so it minds less.
## (Eased 2026-09-26 from 0.2, 0.5, 0.9: a deck's best nine names want
## their fourth copy — the rule of nine, thirty-six spells in four-ofs —
## and from a deep pool the old ramp let the fortieth-best card's first
## copy beat the ninth-best card's fourth.)
const COPY_PENALTY := [0.0, 0.15, 0.35, 0.6]
const FAST_COPY_SCALE := 0.7
## The variety levels the window offers ([member variety]), and what the
## widest moves a card's worth by at most ([constant TASTE_SPAN]) — about
## the gap between a good card and a fair one, so a taste picks among
## the good cards and never lifts junk into the deck.
const VARIETY_LEVELS: Array[int] = [0, 25, 50, 100]
const TASTE_SPAN := 1.5
## How much of a creature's worth its mana value lets through: a
## five-drop is cast most games, an eight-drop is a dead card in half of
## them. Mana values under five pass whole.
const CAST_EASE := {5: 0.9, 6: 0.8, 7: 0.65}
const CAST_EASE_FLOOR := 0.5
## A card whose mana ability makes none of the deck's colours — a Green
## Mana Battery in a blue-black deck — is a rock, whatever its score.
const OFF_COLOR_MANA := 1.0
## Prices for the keywords the duel AI does not price, in the same
## stat-point unit as [constant Evaluator.KEYWORD_VALUE].
const MORE_KEYWORDS := {Mtg.Keyword.HASTE: 0.7, Mtg.Keyword.UNBLOCKABLE: 1.5,
	Mtg.Keyword.FEAR: 1.0}
## What a spell's role is worth — the roles are [method
## AiDeckStudy.classify]'s. A card's value is its best role plus a little
## for each further one.
const ROLE_WORTH := {
	"removal": 2.4, "burn": 2.2, "sweeper": 1.9, "draw": 1.9, "counter": 1.8,
	"tokens": 1.5, "bounce": 1.3, "discard": 1.3, "acceleration": 1.0,
	"reanimation": 1.2, "recursion": 0.9, "pump": 0.9, "land_denial": 0.8,
	"tap_payoff": 0.8, "untap": 0.6, "mill": 0.6, "life_mana": 0.6,
	"x_damage": 0.3, "sacrifice_outlet": 0.3,
}
## What the lean makes of a role, a factor on [constant ROLE_WORTH]: a
## deck of creatures wants its pump and its tokens and not a sweeper
## that kills its own; a deck of spells wants the sweeper, the counters
## and the card draw the more, and has little to pump.
const LEAN_ROLE_SCALE := {
	LEAN_CREATURES: {"pump": 1.6, "tokens": 1.2, "sweeper": 0.5},
	LEAN_BALANCED: {},
	LEAN_SPELLS: {"sweeper": 1.3, "counter": 1.2, "draw": 1.2, "pump": 0.6},
}
## The rarity wishes in words, for the notes and the window.
const RARITY_WORDS := {RARITY_ANY: "any rarity", RARITY_PAUPER: "commons only",
	RARITY_NO_RARES: "no rares, no legends", RARITY_UNCOMMON_UP: "uncommons, rares and legends",
	RARITY_RARES: "rares and legends only"}
## The answer keys ([method AiSideboard.answers]) that make a card BROAD
## — it answers creatures, which every deck has.
const BROAD_ANSWERS: Array[String] = ["creature", "flying"]

## The pool: `name -> copies on offer`, never a basic land (they are
## always free) and never a name the registry does not know.
var pool: Dictionary = {}
## Where the pool came from, for the report — "Fourth Edition and The
## Dark", "the dealt cards", "pool.txt".
var pool_label := "the library"
## The wishes.
var size := 60
## The colours asked for, a [enum Mtg.ManaColor] mask; 0 lets the builder
## choose them all.
var colors := 0
## How many colours the deck may have, 1 to 5.
var max_colors := 2
## A gold deck: multicoloured cards preferred ([constant GOLD_BONUS]),
## and two colours at least.
var gold := false
## The Power Nine ([constant POWER_NINE]): avoided when off, placed
## ahead of the fill when on.
var power_nine := false
var lean := LEAN_BALANCED
var speed := SPEED_MEDIUM
var rarity := RARITY_ANY
var land_kind := LANDS_CLASSIC
## Tournament rules: no banned card (the nine ante cards among them),
## restricted cards one copy.
var tournament := true
## The deck to build AROUND — its non-land cards go in first and its
## colours are the deck's. Null builds from nothing.
var keep: DeckModel = null
## Whether the kept deck's lands go in too, as they are (the AutoDeck
## CLI's `--vary`: a deck held but for a few cards). Off, the lands are
## laid fresh.
var keep_lands := false
## The lands to lay: 0 for the speed's count settled by the curve
## ([method lands_for]); anything else is laid exactly — a varied deck
## keeps its own land count — and then any [member size] will do.
var land_total := 0
## How far the seed's taste for each card moves its worth, 0 to 100
## ([constant TASTE_SPAN], [constant VARIETY_LEVELS]). At 0 the best
## card wins every slot.
var variety := 0
## The roll; 0 asks for a fresh one, and [member roll] then holds it.
var seed := 0
var roll := 0

## What the last [method build] chose, for the window and the notes.
var chosen_colors := 0
## The colours the deck's spells have pips of once it is filled — the
## chosen colours, less any the fill found no card worth its lands in
## ([method _source_strain]). The name is theirs.
var cast_colors := 0
var report: Array[String] = []
## Basic lands laid because the pool ran out of spells.
var short_by := 0

var _rng := RandomNumberGenerator.new()
var _scores: Dictionary = {}
## The seed's taste for each name, `name -> worth moved`, rolled by
## [method build] when [member variety] is above 0.
var _taste: Dictionary = {}
## The lands of each colour the mana base is expected to give, set once
## the colours are chosen ([method _expect_sources]).
var _expected: Dictionary = {}
## The fill's picks in order, so a settled land count can take the last
## back.
var _picked: Array[String] = []
## The colours the fill chose and then let go as splashes the lands
## could not carry ([method _drop_splashes]), and the choice as first
## made, for the report.
var _splashed := 0
var _first_choice := 0
## The colours the wish and the kept cards required, for the report.
var _required := 0


# ------------------------------------------------------------- the pools --

## A pool of [param copies] of every name in [param names] — a whole set,
## or a whole library. Basics and unknown names are left out.
static func pool_from_names(names: Array, copies := 4) -> Dictionary:
	var out := {}
	for name in names:
		var card_name := String(name)
		if not CardRegistry.has_card(card_name) or BASICS.has(card_name):
			continue
		out[card_name] = copies
	return out


## Every card the registry puts in any of [param set_codes], with the
## Extras window's two switches honoured the way the Inventory honours
## them ([method CardRegistry.card_in_set]).
static func pool_from_sets(set_codes: Array, completion_on := true,
		original_on := true, copies := 4) -> Dictionary:
	CardRegistry.ensure_loaded()
	var names: Array = []
	for name in CardRegistry.all_names():
		for code in set_codes:
			if CardRegistry.card_in_set(String(name), String(code), completion_on, original_on):
				names.append(name)
				break
	return pool_from_names(names, copies)


## A pool from counted names — a dealt [member SealedPool.counts], or a
## deck's own [member DeckModel.counts]. Basics and unknown names are
## left out, so a pool never holds what the builder cannot play.
static func pool_from_counts(counts: Dictionary) -> Dictionary:
	var out := {}
	for name in counts:
		var card_name := String(name)
		if not CardRegistry.has_card(card_name) or BASICS.has(card_name):
			continue
		if int(counts[name]) > 0:
			out[card_name] = int(out.get(card_name, 0)) + int(counts[name])
	return out


## A pool from a decklist's text — the same lines a `.deck` file holds
## (`4 Lightning Bolt`, `SB:` lines count too, `#` comments skipped),
## read leniently by [method DeckList.parse]. Names the game does not
## have are listed in [param out_report] and left out; a line that is not
## a card line at all is an error and the pool is empty.
static func pool_from_text(text: String, out_report: Array) -> Dictionary:
	var list := DeckList.new()
	list.parse(text, "pool", false, false)
	if not list.errors.is_empty():
		out_report.append_array(list.errors)
		return {}
	var counts := {}
	for name in list.cards:
		counts[name] = int(counts.get(name, 0)) + 1
	for name in list.sideboard:
		counts[name] = int(counts.get(name, 0)) + 1
	if not list.proxies.is_empty():
		out_report.append("%d name%s the game does not have: %s" % [
			list.proxies.size(), "" if list.proxies.size() == 1 else "s",
			", ".join(list.proxies)])
	return pool_from_counts(counts)


## The basic lands a deck holds.
static func _basics_in(deck: DeckModel) -> int:
	var n := 0
	for land in BASICS:
		n += deck.count_of(String(land))
	return n


## Copies on offer, all names together.
static func pool_total(counts: Dictionary) -> int:
	var n := 0
	for name in counts:
		n += int(counts[name])
	return n


## The pool as a [SealedPool], for the Inventory to offer under the pool
## medallion: the pool's own copies, and [param basics] of each basic
## land, since the builder treats those as free.
func to_sealed_pool(basics := 0) -> SealedPool:
	var out := SealedPool.new()
	out.counts = pool.duplicate()
	for land in BASICS:
		out.counts[land] = maxi(basics, size)
	out.packs.append({"title": "AutoDeck", "cards": out.names()})
	return out


# ------------------------------------------------------------- the build --

## Build the deck. Never null: an empty pool builds a deck of basic
## lands and says so in [member report].
func build() -> DeckModel:
	CardRegistry.ensure_loaded()
	_scores.clear()
	report.clear()
	short_by = 0
	roll = seed if seed != 0 else randi_range(1, 999_999)
	_rng.seed = roll
	if not SIZES.has(size) and land_total <= 0:
		size = 60
	max_colors = clampi(max_colors, 1, 5)
	variety = clampi(variety, 0, 100)
	_roll_taste()
	if gold:
		max_colors = maxi(max_colors, 2)
	if not RARITIES.has(rarity):
		rarity = RARITY_ANY
	if not LAND_KINDS.has(land_kind):
		land_kind = LANDS_CLASSIC
	var out := DeckModel.new()
	var limit := DeckModel.duplicates_allowed(size)
	if limit <= 0:
		limit = 4
	# The kept cards first: they are the deck's, whatever the pool holds.
	var required := colors
	var kept := 0
	var kept_lands := 0
	if keep != null:
		for name in keep.names():
			var card_name := String(name)
			var data := DeckModel._card(card_name)
			if data == null:
				continue
			if data.is_land():
				if keep_lands:
					for i in int(keep.counts[card_name]):
						out.add(card_name)
					kept_lands += int(keep.counts[card_name])
					kept += int(keep.counts[card_name])
				continue
			required |= data.color_mask() & ~Mtg.ManaColor.C
			for i in int(keep.counts[card_name]):
				out.add(card_name)
				kept += 1
	_required = required & ~Mtg.ManaColor.C
	var candidates := _candidates(limit)
	chosen_colors = _choose_colors(candidates, required)
	var lands_wanted := land_total if land_total > 0 else int(LANDS[size_key()][speed])
	_expect_sources(candidates, lands_wanted)
	_picked.clear()
	if power_nine:
		_place_power(out, candidates, size - lands_wanted)
	_fill_spells(out, candidates, size - lands_wanted)
	if land_total <= 0 and short_by == 0:
		lands_wanted = _settle_lands(out, candidates, lands_wanted)
	# After the settling: more lands take the fill's last picks back,
	# and a splash of three cards is two once they are.
	_drop_splashes(out, candidates, size - lands_wanted, required, lands_wanted)
	cast_colors = _pips_of(out)
	if cast_colors == 0:
		cast_colors = chosen_colors
	_lay_lands(out, candidates, lands_wanted - kept_lands)
	out.deck_name = deck_name()
	_write_report(out, kept, kept_lands, lands_wanted)
	out.notes = "\n".join(report)
	return out


## The size the tables go by — 40 or 60, whatever the deck's total.
func size_key() -> int:
	return 40 if size < 50 else 60


## The seed's taste for every name in the pool, in name order so the
## same seed tastes the same whatever order the pool came in — and
## nothing at all at variety 0, so the generator is untouched and the
## deck is the one it always was.
func _roll_taste() -> void:
	_taste.clear()
	if variety <= 0:
		return
	var names: Array = pool.keys()
	names.sort()
	var span := TASTE_SPAN * variety / 100.0
	for name in names:
		_taste[name] = (_rng.randf() * 2.0 - 1.0) * span


## A card's worth as this seed tastes it: [method worth] moved by the
## seed's taste for the name ([member variety]).
func tasted(data: CardData) -> float:
	return worth(data) + float(_taste.get(data.card_name, 0.0))


## The deck's name from what was built: "Red-Green Beatdown" — the
## colours its spells cast ([member cast_colors]).
func deck_name() -> String:
	var archetype: Dictionary = {
		LEAN_CREATURES: {SPEED_FAST: "Rush", SPEED_MEDIUM: "Beatdown", SPEED_SLOW: "Stompy"},
		LEAN_BALANCED: {SPEED_FAST: "Aggro", SPEED_MEDIUM: "Midrange", SPEED_SLOW: "Big"},
		LEAN_SPELLS: {SPEED_FAST: "Tempo", SPEED_MEDIUM: "Spells", SPEED_SLOW: "Control"},
	}
	return "%s %s" % [color_phrase(cast_colors if cast_colors != 0 else chosen_colors),
		String(archetype[lean][speed])]


## The colours the deck's non-land cards have pips of, as a mask.
static func _pips_of(out: DeckModel) -> int:
	var mask := 0
	for name in out.names():
		var data := DeckModel._card(String(name))
		if data == null or data.is_land():
			continue
		mask |= data.color_mask() & ~Mtg.ManaColor.C
	return mask


## "Mono-White", "Blue-Black", "White-Blue-Black" — in WUBRG order.
static func color_phrase(mask: int) -> String:
	var names: PackedStringArray = []
	for color in Mtg.WUBRG:
		if mask & color:
			names.append(String(Mtg.COLOR_NAMES[color]))
	if names.is_empty():
		return "Colourless"
	if names.size() == 1:
		return "Mono-%s" % names[0]
	return "-".join(names)


## The pool's playable cards as `[CardData, copies allowed]`, the copies
## the smaller of the pool's and the rules', sorted by name so a seed
## means the same deck whatever order the pool came in.
func _candidates(limit: int) -> Array:
	var out: Array = []
	var names: Array = pool.keys()
	names.sort()
	for name in names:
		var card_name := String(name)
		var data := DeckModel._card(card_name)
		if data == null:
			continue
		if rarity != RARITY_ANY:
			var rank := int(RARITY_RANK.get(DeckStats.rarity_tier(data), 0))
			var span: Array = RARITY_RANGE[rarity]
			if rank < int(span[0]) or rank > int(span[1]):
				continue
		if not power_nine and POWER_NINE.has(card_name):
			continue
		var cap := mini(int(pool[card_name]), limit)
		if tournament:
			if DeckFormat.BANNED.has(card_name):
				continue
			if DeckFormat.RESTRICTED.has(card_name):
				cap = mini(cap, 1)
		if (data.supertypes & Mtg.Supertype.LEGENDARY) != 0:
			cap = mini(cap, LEGEND_CAP)
		if cap > 0:
			out.append([data, cap])
	return out


## Every colour set the wishes allow, rated by the sum of its best
## castable spells' scores ON THE MANA THAT SET WOULD BE LAID ([method
## _mask_worth]: each copy after the first worth less, as the fill will
## find, and each card less what its pips strain the lands the set can
## give it), with one per cent off for every extra colour so that two
## sets worth the same go to the simpler mana. The colours asked for
## are in every set; asking for more than [member max_colors] widens it.
## A gold deck is two colours at least, even from a pool with no gold
## card in it — a mono-coloured gold deck is a contradiction.
func _choose_colors(candidates: Array, required: int) -> int:
	var must := required & ~Mtg.ManaColor.C
	var most := maxi(max_colors, _count_colors(must))
	var least := 2 if gold else 1
	var best_mask := must
	var best_worth := -1.0
	var spells := int(size - (land_total if land_total > 0 else int(LANDS[size_key()][speed])))
	for mask in range(1, 32):
		var n := _count_colors(mask)
		if (mask & must) != must or n > most or n < least:
			continue
		var worth := _mask_worth(candidates, mask, spells, must)
		worth *= 1.0 - 0.01 * (_count_colors(mask) - 1)
		if worth > best_worth:
			best_worth = worth
			best_mask = mask
	return best_mask


static func _count_colors(mask: int) -> int:
	var n := 0
	for color in Mtg.WUBRG:
		if mask & color:
			n += 1
	return n


## The sum of the top [param slots] castable spell scores under
## [param mask], copies after the first discounted as the fill discounts
## them, and each card less what its pips would strain the mana base
## the mask gets ([method _mana_expected], [method _source_strain]) —
## so a second colour is chosen for what its cards are worth on the
## lands they would have, and a pool whose second-best colour is all
## double pips builds mono. (Rated without the strain, the choice
## reached for two colours the fill then could not carry, and the
## lands were laid for a splash.)
func _mask_worth(candidates: Array, mask: int, slots: int, must: int) -> float:
	var lands := land_total if land_total > 0 else int(LANDS[size_key()][speed])
	var expected := _mana_expected(candidates, mask, slots, lands, must)
	var values: Array[float] = []
	for entry in candidates:
		var data: CardData = entry[0]
		if data.is_land() or not castable(data, mask):
			continue
		var value := tasted(data) - _source_strain(data, expected)
		for n in int(entry[1]):
			values.append(value - COPY_PENALTY[mini(n, COPY_PENALTY.size() - 1)])
	values.sort()
	values.reverse()
	var worth := 0.0
	for i in mini(slots, values.size()):
		worth += values[i]
	return worth


## THE MANA A COLOUR SET WOULD BE LAID: [param lands] split among the
## colours of [param mask] as [method _lay_lands] splits them, for the
## best [param slots] cards castable under it at their plain worth —
## each colour's most demanding want ([method sources_for]) times the
## square root of its pips — and never under an even share for a colour
## asked for or kept ([param must]), so the fill rates its cards as a
## colour the deck is and not as a splash. The plain worth, because the split is
## about which colours the good cards are in, not what the split will
## then cost them: that is [method _source_strain]'s reading of it.
func _mana_expected(candidates: Array, mask: int, slots: int, lands: int,
		must: int) -> Dictionary:
	var rated: Array = []
	for entry in candidates:
		var data: CardData = entry[0]
		if data.is_land() or not castable(data, mask):
			continue
		rated.append([tasted(data), data, int(entry[1])])
	rated.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var pips := {}
	var need := {}
	var taken := 0
	for row in rated:
		if taken >= slots:
			break
		var data: CardData = row[1]
		var copies := mini(int(row[2]), slots - taken)
		taken += copies
		for color in data.cost.colored:
			if (mask & int(color)) != 0:
				var pip := int(data.cost.colored[color])
				pips[color] = int(pips.get(color, 0)) + pip * copies
				need[color] = maxi(int(need.get(color, 0)),
					sources_for(pip, data.cost.mana_value(), size_key()))
	var weight := {}
	var weight_total := 0.0
	for color in pips:
		weight[color] = float(need[color]) * sqrt(float(pips[color]))
		weight_total += float(weight[color])
	var even := float(lands) / maxi(_count_colors(mask), 1)
	var expected := {}
	for color in Mtg.WUBRG:
		if (mask & color) == 0:
			continue
		var share := even if weight_total <= 0.0 \
			else lands * float(weight.get(color, 0.0)) / weight_total
		expected[color] = maxf(share, even) if (must & color) != 0 else share
	return expected


## Whether every coloured pip of [param data] is in [param mask].
static func castable(data: CardData, mask: int) -> bool:
	return (data.color_mask() & ~Mtg.ManaColor.C & ~mask) == 0


## The Power Nine ahead of the fill: one copy of each the pool and the
## rules allow — the Lotus and the Moxen whatever the colours, the blue
## three when the deck is blue — as long as the spell slots last. The
## fill then counts them in its curve (a Mox is a first-turn play) and
## may take further copies where the rules allow four.
func _place_power(out: DeckModel, candidates: Array, slots: int) -> void:
	var placed := 0
	for name in out.names():
		var data := DeckModel._card(String(name))
		if data != null and not data.is_land():
			placed += int(out.counts[name])
	for entry in candidates:
		if placed >= slots:
			break
		var data: CardData = entry[0]
		if not POWER_NINE.has(data.card_name) or not castable(data, chosen_colors):
			continue
		if out.count_of(data.card_name) >= int(entry[1]):
			continue
		out.add(data.card_name)
		placed += 1


## The greedy fill: [param slots] non-land cards, each the best worth
## after the nudges. Nothing castable left stops it short, and the lands
## make up the difference ([method _lay_lands]). THE COLOURS ASKED FOR
## are in the deck: a required colour under [constant SPLASH_CARDS]
## cards is a firm nudge on every card with a pip of it, the way the
## curve is — a wish for green is a wish for green cards, not for
## Forests — and a five-colour wish from a pool whose red is deepest
## still ends with a card or three of each.
func _fill_spells(out: DeckModel, candidates: Array, slots: int) -> void:
	var curve: Array = CURVES[speed]
	var wanted: Array[float] = []
	for share in curve:
		wanted.append(float(share) * slots)
	var creatures_wanted := float(CREATURE_SHARE[lean]) * slots
	var spells_wanted := slots - creatures_wanted
	var have: Array[int] = [0, 0, 0, 0, 0]
	var creatures_have := 0
	var placed := 0
	var quota := int(SPLASH_CARDS[size_key()])
	var colors_have := {}
	# What the kept cards already take up.
	for name in out.names():
		var data := DeckModel._card(String(name))
		if data == null or data.is_land():
			continue
		var copies := int(out.counts[name])
		have[_bucket(data)] += copies
		if data.is_creature():
			creatures_have += copies
		placed += copies
		for color in Mtg.WUBRG:
			if (data.color_mask() & color) != 0:
				colors_have[color] = int(colors_have.get(color, 0)) + copies
	# The castable candidates priced once — `[data, copies, value,
	# bucket]` — since the colours are chosen and the strains do not move
	# while the deck fills; the loop below adds only the nudges. (Priced
	# in the loop, a 60-card build from the whole library scored every
	# card forty times over.)
	var picks: Array = []
	for entry in candidates:
		var data: CardData = entry[0]
		if data.is_land() or not castable(data, chosen_colors):
			continue
		picks.append([data, int(entry[1]),
			tasted(data) - _source_strain(data) - _off_color_mana(data), _bucket(data)])
	var copy_scale := FAST_COPY_SCALE if speed == SPEED_FAST else 1.0
	while placed < slots:
		var best: CardData = null
		var best_value := -INF
		for pick in picks:
			var data: CardData = pick[0]
			var n := out.count_of(data.card_name)
			if n >= int(pick[1]):
				continue
			var bucket := int(pick[3])
			var value: float = pick[2]
			# The curve and the lean are both firm nudges ([constant
			# NUDGE]). A soft curve — 0.9 a share, floored at -1.5 — let
			# the score walk over it: a slow deck kept six one-drops and
			# a fast deck ran its two-drops a third under the wish; a 0.8
			# lean left a "more spells" deck at the balanced share, the
			# library's creatures being that much deeper than its spells.
			value += clampf(NUDGE * (wanted[bucket] - have[bucket]) / maxf(wanted[bucket], 1.0),
				-NUDGE_CAP, NUDGE_CAP)
			if data.is_creature():
				value += clampf(NUDGE * (creatures_wanted - creatures_have) / maxf(creatures_wanted, 1.0),
					-NUDGE_CAP, NUDGE_CAP)
			else:
				value += clampf(NUDGE * (spells_wanted - (placed - creatures_have)) / maxf(spells_wanted, 1.0),
					-NUDGE_CAP, NUDGE_CAP)
			value -= COPY_PENALTY[mini(n, COPY_PENALTY.size() - 1)] * copy_scale
			for color in Mtg.WUBRG:
				if (_required & color) != 0 and (data.color_mask() & color) != 0:
					var short := quota - int(colors_have.get(color, 0))
					if short > 0:
						value += NUDGE * short / quota
			# A hair of chance, so two builds from one pool are not one deck.
			value += _rng.randf() * 0.05
			if value > best_value:
				best_value = value
				best = data
		if best == null:
			break
		out.add(best.card_name)
		_picked.append(best.card_name)
		have[_bucket(best)] += 1
		if best.is_creature():
			creatures_have += 1
		placed += 1
		for color in Mtg.WUBRG:
			if (best.color_mask() & color) != 0:
				colors_have[color] = int(colors_have.get(color, 0)) + 1
	short_by = slots - placed


## THE SPLASH THE LANDS CANNOT CARRY (2026-09-26): a colour the fill
## took fewer than [constant SPLASH_CARDS] cards of is no colour to
## build on — the lands laid for it ([method _lay_lands]) are two or
## three, and a five-drop on three Forests is cast the game after it was
## wanted. The colour leaves the deck, its cards with it, and the fill
## picks their slots again from the colours that stay, until every
## colour left has the cards to be laid for. A colour asked for, or in
## the kept cards, stays however thin — the wish is the wish — and so
## does a gold deck's second colour; the report says what it cost
## ([method _thin_colors]). Runs once the land count is settled, on
## the [param slots] the settled count leaves; and a deck the pool
## could not fill is left as it is — every castable card is in it
## already, and there is nothing to pick again (a pasted list of four
## Bolts, two Angels and a Disenchant is those seven cards, not the
## Bolts alone).
func _drop_splashes(out: DeckModel, candidates: Array, slots: int, required: int,
		lands: int) -> void:
	_first_choice = chosen_colors
	_splashed = 0
	var must := required & ~Mtg.ManaColor.C
	while short_by == 0 and _count_colors(chosen_colors) > (2 if gold else 1):
		var counts := _cards_of_colors(out)
		var thin := 0
		for color in Mtg.WUBRG:
			if (chosen_colors & color) == 0 or (must & color) != 0:
				continue
			if int(counts.get(color, 0)) < int(SPLASH_CARDS[size_key()]):
				thin = color
				break
		if thin == 0:
			break
		for name in out.names():
			var card_name := String(name)
			var data := DeckModel._card(card_name)
			if data == null or data.is_land() or (data.color_mask() & thin) == 0:
				continue
			out.remove_all(card_name)
			while _picked.has(card_name):
				_picked.erase(card_name)
		chosen_colors &= ~thin
		_splashed |= thin
		_expect_sources(candidates, lands)
		_fill_spells(out, candidates, slots)


## The colours of the deck whose lands, once laid, are under what one
## late pip wants ([method sources_for]): a colour asked for or kept
## stays however few its cards, a gold deck's second colour too, and
## the builder's own second colour is laid for by its pips — the
## report owns each ([method _write_report]).
func _thin_colors(out: DeckModel) -> int:
	var thin := 0
	for color in Mtg.WUBRG:
		if (cast_colors & color) == 0:
			continue
		if _sources_in(out, color) < sources_for(1, 5, size_key()):
			thin |= color
	return thin


## The lands in [param out] that make [param color].
func _sources_in(out: DeckModel, color: int) -> int:
	var sources := 0
	for name in out.names():
		var data := DeckModel._card(String(name))
		if data != null and data.is_land() and (produces(data) & color) != 0:
			sources += int(out.counts[name])
	return sources


## "2 cards of it on 3 sources" — the cards with a pip of [param thin],
## one colour, and the lands that make it.
func _thin_words(out: DeckModel, thin: int) -> String:
	var cards := 0
	var sources := 0
	for name in out.names():
		var data := DeckModel._card(String(name))
		if data == null:
			continue
		var copies := int(out.counts[name])
		if data.is_land():
			if (produces(data) & thin) != 0:
				sources += copies
		elif (data.color_mask() & thin) != 0:
			cards += copies
	return "%d card%s of it on %d source%s" % [cards, "" if cards == 1 else "s",
		sources, "" if sources == 1 else "s"]


## The non-land cards of [param out] with a pip of each colour, by
## colour; a gold card counts for each of its colours.
func _cards_of_colors(out: DeckModel) -> Dictionary:
	var counts := {}
	for name in out.names():
		var data := DeckModel._card(String(name))
		if data == null or data.is_land():
			continue
		for color in Mtg.WUBRG:
			if (data.color_mask() & color) != 0:
				counts[color] = int(counts.get(color, 0)) + int(out.counts[name])
	return counts


## The land count the filled curve asks for ([method lands_for]), within
## [constant LAND_PLAY] of the speed's [param lands_wanted]: more lands
## take the fill's last picks back, fewer let it pick again. Returns
## the count settled on.
func _settle_lands(out: DeckModel, candidates: Array, lands_wanted: int) -> int:
	var settled := clampi(lands_for(_average_mana(out), _cheap_mana_or_draw(out), size_key()),
		lands_wanted - LAND_PLAY, lands_wanted + LAND_PLAY)
	if settled > lands_wanted:
		var back := settled - lands_wanted
		while back > 0 and not _picked.is_empty():
			out.remove(_picked.pop_back())
			back -= 1
		settled -= back
	elif settled < lands_wanted:
		_fill_spells(out, candidates, size - settled)
		if short_by > 0:
			settled += short_by
			short_by = 0
	return settled


## Karsten's fit for the lands a curve wants ([constant LAND_BASE],
## [constant LAND_PER_MANA], [constant LAND_PER_CHEAP]) for a deck of
## [param size] cards — 60, or 40 at two thirds: an average mana value
## of 2.0 asks for 23 lands in 60, 3.0 for 25, 3.5 for 26, and every
## cheap mana or draw spell takes a little off.
static func lands_for(average_mana: float, cheap: int, size: int) -> int:
	var lands := LAND_BASE + LAND_PER_MANA * average_mana - LAND_PER_CHEAP * cheap
	if size < 50:
		lands *= 2.0 / 3.0
	return roundi(lands)


## The average mana value of the deck's non-land cards.
static func _average_mana(out: DeckModel) -> float:
	var mana := 0
	var spells := 0
	for name in out.names():
		var data := DeckModel._card(String(name))
		if data == null or data.is_land():
			continue
		mana += data.cost.mana_value() * int(out.counts[name])
		spells += int(out.counts[name])
	return float(mana) / maxi(spells, 1)


## The deck's cheap mana and card-draw spells, as Karsten counts them:
## non-land cards of two mana or less that make mana or draw cards.
static func _cheap_mana_or_draw(out: DeckModel) -> int:
	var cheap := 0
	for name in out.names():
		var data := DeckModel._card(String(name))
		if data == null or data.is_land() or cast_value(data) > 2:
			continue
		var roles := AiDeckStudy.classify(data)
		if produces(data) != 0 or roles.has("draw") or roles.has("acceleration"):
			cheap += int(out.counts[name])
	return cheap


## The curve bucket of a spell: 0 for a cast value of 0 and 1, then 2,
## 3, 4, and 5 or more.
static func _bucket(data: CardData) -> int:
	return clampi(cast_value(data) - 1, 0, 4)


## The mana a spell is cast for, on the curve: its mana value, with
## every X counted [constant X_AS] — a Fireball is no one-drop, and
## bucketed as one it crowded the Bolts out of the deck's first turn
## (2026-09-26). Karsten's land count ([method lands_for]) keeps the
## printed value, as his fit does.
static func cast_value(data: CardData) -> int:
	return data.cost.mana_value() + X_AS * data.cost.x_count


## The rock: a mana ability that makes only colours the deck is not.
func _off_color_mana(data: CardData) -> float:
	var made := produces(data)
	if made == 0 or (made & Mtg.ManaColor.C) != 0:
		return 0.0
	return 0.0 if (made & chosen_colors) != 0 else OFF_COLOR_MANA


## The lands of each colour the mana base is expected to give ([member
## _expected]), for the fill: what the chosen colours would be laid
## ([method _mana_expected]) — the same reading the colours were chosen
## by, so the fill can tell a card the lands will carry from one they
## will not. A mono-coloured deck expects every land its colour.
func _expect_sources(candidates: Array, lands: int) -> void:
	_expected = _mana_expected(candidates, chosen_colors, size - lands, lands, _required)


## What a card's pips cost it in the fill: [constant SOURCE_STRAIN] for
## every source of a colour Karsten's counts ([method sources_for]) say
## it wants and the mana base is not expected to give ([member
## _expected]). A single pip in a mono deck or the main colour costs
## nothing; a double pip of the second colour, or anything of a third,
## costs what it is short.
func _source_strain(data: CardData, expected: Dictionary = _expected) -> float:
	var strain := 0.0
	for color in data.cost.colored:
		var pips := int(data.cost.colored[color])
		var short := sources_for(pips, data.cost.mana_value(), size_key()) \
			- float(expected.get(color, 0.0))
		if short > 0.0:
			strain += SOURCE_STRAIN * short
	return strain


## Karsten's count of the lands of one colour a deck of [param size]
## cards wants to cast a card of [param pips] pips of it and [param
## mana_value] mana on time ([constant SOURCES]); a fourth pip and
## beyond one more each.
static func sources_for(pips: int, mana_value: int, size: int) -> int:
	if pips <= 0:
		return 0
	var table: Dictionary = SOURCES[40 if size < 50 else 60]
	var row: Array = table[clampi(pips, 1, 3)]
	return int(row[clampi(mana_value, 1, 5) - 1]) + maxi(pips - 3, 0)


## The lands: in a non-classic deck the pool's non-basic lands first
## ([method _lay_nonbasics]), then — or, in a classic deck, only —
## basics split by what the spells want ([method sources_for]: each
## colour's hardest card's count, weighted by the square root of the
## colour's pips, so a splash gets the sources its card wants and not
## the main colour's), less the sources the deck's non-basic lands
## already give, every colour with a pip getting at least two. A deck
## the pool could not fill takes the difference in basics as well.
func _lay_lands(out: DeckModel, candidates: Array, lands: int) -> void:
	var total := lands + short_by
	var laid := 0
	if land_kind == LANDS_NONCLASSIC:
		laid = _lay_nonbasics(out, candidates, lands)
	# What the spells want of each colour, and what the lands in already give.
	var pips := {}
	var need := {}
	var have := {}
	var lands_in := 0
	for name in out.names():
		var data := DeckModel._card(String(name))
		if data == null:
			continue
		var copies := int(out.counts[name])
		if data.is_land():
			lands_in += copies
			var made := produces(data)
			for color in Mtg.WUBRG:
				if made & color & chosen_colors:
					have[color] = int(have.get(color, 0)) + copies
			continue
		for color in data.cost.colored:
			if chosen_colors & int(color):
				var pip := int(data.cost.colored[color])
				pips[color] = int(pips.get(color, 0)) + pip * copies
				need[color] = maxi(int(need.get(color, 0)),
					sources_for(pip, data.cost.mana_value(), size_key()))
	var basics_left := total - laid
	var shares := {}
	var colors_used: Array = []
	for color in Mtg.WUBRG:
		if chosen_colors & color:
			colors_used.append(color)
	if pips.is_empty():
		# Nothing coloured to cast: the colours asked for, evenly.
		for color in colors_used:
			pips[color] = 1
			need[color] = 1
	var weight := {}
	var weight_total := 0.0
	for color in colors_used:
		if int(pips.get(color, 0)) == 0:
			continue
		weight[color] = float(need[color]) * sqrt(float(pips[color]))
		weight_total += float(weight[color])
	# Each colour's target is its share of every land in the deck; the
	# basics make up what the lands already in do not give.
	var sources_total := lands_in + basics_left
	var target := {}
	var given := 0
	for color in weight:
		target[color] = sources_total * float(weight[color]) / weight_total
		var share := maxi(int(floor(float(target[color]))) - int(have.get(color, 0)), 0)
		share = maxi(share, 2 - int(have.get(color, 0)))
		shares[color] = share
		given += share
	# Largest remainder for what floor left over, and a trim when the
	# floors of two already exceed the room.
	var order: Array = shares.keys()
	order.sort_custom(func(a: int, b: int) -> bool:
		var ra := float(target[a]) - int(have.get(a, 0)) - int(shares[a])
		var rb := float(target[b]) - int(have.get(b, 0)) - int(shares[b])
		if ra != rb:
			return ra > rb
		return a < b)
	var i := 0
	while given < basics_left and not order.is_empty():
		shares[order[i % order.size()]] += 1
		given += 1
		i += 1
	while given > basics_left and not order.is_empty():
		var most: int = order[0]
		for color in order:
			if int(shares[color]) > int(shares[most]):
				most = color
		if int(shares[most]) <= 0:
			break
		shares[most] -= 1
		given -= 1
	for color in colors_used:
		var land := _basic_for(int(color))
		for n in int(shares.get(color, 0)):
			out.add(land)


static func _basic_for(color: int) -> String:
	for land in BASICS:
		if int(BASICS[land]) == color:
			return String(land)
	return "Plains"


## The non-classic mana base: the pool's non-basic lands worth laying
## ([method land_worth], more than [constant LAND_FLOOR]), best first —
## the deck's dual lands and City of Brass before the lands with
## abilities — up to [constant NONBASIC_SHARE] of the lands and
## [constant NONBASIC_CAP] copies of one; the lands that make no colour
## of the deck within [constant COLORLESS_ROOM] and those that make no
## mana within [constant NO_MANA_ROOM], so the basics still carry the
## colours. Returns how many were laid.
func _lay_nonbasics(out: DeckModel, candidates: Array, land_total: int) -> int:
	var room := int(floor(NONBASIC_SHARE * land_total))
	var colorless_room := int(COLORLESS_ROOM[size_key()])
	var no_mana_room := int(NO_MANA_ROOM[size_key()])
	var lands: Array = []
	for entry in candidates:
		var data: CardData = entry[0]
		if not data.is_land():
			continue
		var worth := land_worth(data)
		if worth <= LAND_FLOOR:
			continue
		lands.append([data, mini(int(entry[1]), NONBASIC_CAP), worth,
			_count_colors(produces(data) & chosen_colors)])
	lands.sort_custom(func(a: Array, b: Array) -> bool:
		if a[2] != b[2]:
			return a[2] > b[2]
		if a[3] != b[3]:
			return a[3] > b[3]
		return (a[0] as CardData).card_name < (b[0] as CardData).card_name)
	var laid := 0
	for row in lands:
		var data: CardData = row[0]
		var off_color: bool = int(row[3]) == 0
		var no_mana := produces(data) == 0
		for i in int(row[1]):
			if laid >= room:
				return laid
			if off_color and (colorless_room <= 0 or (no_mana and no_mana_room <= 0)):
				break
			out.add(data.card_name)
			laid += 1
			if off_color:
				colorless_room -= 1
				if no_mana:
					no_mana_room -= 1
	return laid


## What a non-basic land is worth to the deck, for the non-classic mana
## base: a point for each of the deck's colours it makes and half a
## point more when it makes two or more (a dual of the deck's colours is
## two and a half, City of Brass in a three-colour deck three and a
## half); four tenths for colourless mana and half a point off for
## making no mana at all; half a point for each ability beyond the mana
## (Mishra's Factory's two, Karakas's one) and a share of [constant
## ROLE_WORTH] for the roles the duel AI reads off them; [constant
## LAND_NOTES] for what it cannot read; half a point off for a land that
## hurts its owner (City of Brass, a painland). A land that makes only
## colours the deck is not is worth nothing to it, and a basic is worth
## one ([constant LAND_FLOOR]).
func land_worth(data: CardData) -> float:
	var made := produces(data)
	var colored := made & ~Mtg.ManaColor.C
	var ours := _count_colors(colored & chosen_colors)
	if colored != 0 and ours == 0:
		return 0.0
	var worth := float(ours)
	if ours >= 2:
		worth += 0.5
	elif made != 0 and ours == 0:
		worth += 0.4
	elif made == 0:
		worth -= 0.5
	worth += 0.5 * data.activated_abilities.size()
	for role in AiDeckStudy.classify(data):
		if role == "tap_payoff":
			continue
		if role == "removal" and AiSideboard.answers(data).is_empty():
			continue
		worth += 0.3 * float(ROLE_WORTH.get(role, 0.0))
	worth += float(LAND_NOTES.get(data.card_name, 0.0))
	if "damage to you" in data.oracle_text.to_lower():
		worth -= 0.5
	return maxf(worth, 0.0)


## The cards the builder chose in [param deck] — its counts less the
## basic lands and less the [param kept] cards — for [method
## difference]: what one build of a wish has that another has not.
static func builders_cards(deck: DeckModel, kept: DeckModel = null) -> Dictionary:
	var out := {}
	for name in deck.names():
		if BASICS.has(name):
			continue
		var copies := int(deck.counts[name])
		if kept != null:
			copies -= kept.count_of(String(name))
		if copies > 0:
			out[name] = copies
	return out


## How different two decks are, 0 to 1, over their builders' cards
## ([method builders_cards], `name -> copies`): one less the copies they
## share over the larger of the two — a deck with four cards swapped
## out of thirty-six is 0.11 different, a deck with none in common 1.
static func difference(a: Dictionary, b: Dictionary) -> float:
	var shared := 0
	var a_total := 0
	var b_total := 0
	for name in a:
		a_total += int(a[name])
		if b.has(name):
			shared += mini(int(a[name]), int(b[name]))
	for name in b:
		b_total += int(b[name])
	var larger := maxi(a_total, b_total)
	if larger <= 0:
		return 0.0
	return 1.0 - float(shared) / larger


## The colours a card's mana abilities make, as a mask.
static func produces(data: CardData) -> int:
	var mask := 0
	for ability in data.mana_abilities:
		for pair in ability.produces:
			mask |= int(pair[0])
	return mask


# ------------------------------------------------------------- the score --

## How good a card is on its own, in the pool's own terms — see the class
## doc. Cached by name for the build.
func score(data: CardData) -> float:
	if _scores.has(data.card_name):
		return float(_scores[data.card_name])
	var value := _creature_score(data) if data.is_creature() else _spell_score(data)
	_scores[data.card_name] = value
	return value


## The score priced for the speed: [method score] times the speed's
## [constant TEMPO] for the card's mana value, and [constant GOLD_BONUS]
## on top for a multicoloured card in a gold deck, [constant
## POWER_BONUS] for one of the Power Nine when they are allowed. This is
## what the colour choice and the fill go by, so a fast deck is drawn to
## the colours with the best one-drops, a slow deck to the colours with
## the best big spells, a gold deck to the colours with the gold cards
## and a Power Nine deck towards blue when blue is close.
func worth(data: CardData) -> float:
	var value := score(data) * float(TEMPO[speed][_bucket(data)])
	if gold and is_gold(data):
		value += GOLD_BONUS
	if power_nine and POWER_NINE.has(data.card_name):
		value += POWER_BONUS
	return value


## A multicoloured card: two colours or more in its cost.
static func is_gold(data: CardData) -> bool:
	return _count_colors(data.color_mask() & ~Mtg.ManaColor.C) >= 2


## Power counts for more than toughness — the deck is built to win —
## and a creature that cannot hurt anyone (no power, or a defender) is
## worth half its body, its abilities apart. The body's worth is then
## measured against par — twice the mana value — so a 2/2 for two and a
## 4/4 for four score the same, a 2/1 for one scores better than either,
## and a fat thing for eight is not worth what its stats say ([constant
## CAST_EASE]). Where on the curve the deck's creatures land is the
## fill's business, not the score's ([method _fill_spells]).
func _creature_score(data: CardData) -> float:
	var worth := 1.2 * data.power + 0.8 * data.toughness
	for keyword in data.keywords:
		worth += float(Evaluator.KEYWORD_VALUE.get(keyword, 0.0))
		worth += float(MORE_KEYWORDS.get(keyword, 0.0))
	if not data.landwalk.is_empty():
		worth += 0.8
	if data.protection_from != 0:
		worth += 0.6
	if data.rampage > 0:
		worth += 0.3
	if data.power <= 0 or data.keywords.has(Mtg.Keyword.DEFENDER):
		worth *= 0.5
	if not data.mana_abilities.is_empty():
		worth += 1.2
	for ability in data.activated_abilities:
		var regenerates := false
		for effect in ability.effects:
			if effect is RegenerateEffect:
				regenerates = true
		worth += 0.6 if regenerates else 0.5
	if not data.triggered_abilities.is_empty():
		worth += 0.3
	if not data.static_abilities.is_empty():
		worth += 0.4
	worth -= _drawbacks(data)
	var mana := maxi(data.cost.mana_value(), 1)
	var ease := 1.0 if mana < 5 else float(CAST_EASE.get(mana, CAST_EASE_FLOOR))
	# Par is a body of twice the mana value — a 2/2 for two, a 4/4 for
	# four — and par scores about 2.5, where a fair spell scores too.
	return maxf(worth / (2.0 * mana + 1.0) * 3.0 * ease, 0.0)


## The upkeep clauses and the like, read off the oracle text the way the
## duel AI reads roles off it.
static func _drawbacks(data: CardData) -> float:
	var line := data.oracle_text.to_lower()
	var cost := 0.0
	if "cumulative upkeep" in line:
		cost += 1.5
	elif "upkeep" in line and ("sacrifice" in line or "pay" in line
			or "damage to you" in line or "lose" in line):
		cost += 0.8
	if "can't block" in line:
		cost += 0.5
	if "doesn't untap" in line or "does not untap" in line:
		cost += 1.0
	if "can't attack" in line:
		cost += 0.8
	if "sacrifice" in line and ("end of turn" in line or "end step" in line):
		cost += 0.8
	# A creature that enters and asks for another, a Forest, three
	# Forests or a card — or leaves — costs that on top of itself: a
	# card from the hand one, a permanent from the table two (a land is
	# a turn), each one asked for again — so an 8/8 for five that eats
	# three Forests is a 5/5 for five; a coin flip loses it half its combats
	# (2026-09-26: a black-green deck of four Kjeldoran Dead, four Plant
	# Elementals and four Primeval Forces).
	var enters := line.find("enters, sacrifice")
	if enters < 0:
		enters = line.find("enters the battlefield, sacrifice")
	if enters >= 0:
		var clause := line.substr(enters, 80)
		var asked := 3.0 if " three " in clause else (2.0 if " two " in clause else 1.0)
		cost += asked * (1.0 if "unless you discard" in clause else 2.0) \
			if "unless you" in clause else asked
	if "flip a coin" in line:
		cost += 0.6
	return cost


func _spell_score(data: CardData) -> float:
	var roles := AiDeckStudy.classify(data)
	var answers := AiSideboard.answers(data)
	var best := 0.0
	var others := 0
	var scale: Dictionary = LEAN_ROLE_SCALE[lean]
	for role in roles:
		var worth := float(ROLE_WORTH.get(role, 0.0)) * float(scale.get(role, 1.0))
		if role == "removal" and answers.is_empty():
			# Removal the sideboard reads no answer off is removal of
			# something no deck need have — a Wall (Tunnel), a land
			# (Stone Rain), an Aura on a land (Pyramids). Not a slot.
			continue
		if role == "burn":
			# Burn by its damage: Lightning Bolt's three is the unit,
			# Psychic Purge's one is a third of a card, and an X spell
			# is whatever the mana is.
			var intent := EffectIntent.read(_spell_effects(data), data.card_name)
			if not intent.damage_uses_x:
				worth *= clampf(intent.damage / 3.0, 0.3, 1.3)
		if worth > best:
			if best > 0.0:
				others += 1
			best = worth
		elif worth > 0.0:
			others += 1
	if data.aura_steals:
		# Control Magic: the duel AI reads no role off a steal, and it
		# is removal and a creature in one.
		best = maxf(best, float(ROLE_WORTH["removal"]))
	var value := 0.5 + best + 0.25 * mini(others, 2)
	if best == 0.0:
		# A card the duel AI reads no role off: an enchantment or an
		# artifact that does something quieter. Worth a look, not a slot.
		value = 1.1 if not data.static_abilities.is_empty() else 0.8
	if data.is_aura():
		value -= 0.2
	if speed == SPEED_SLOW and roles.has("artifact_mana"):
		value += 0.4
	elif speed == SPEED_FAST and roles.has("artifact_mana"):
		value -= 0.3
	# Priced at the mana it is cast for ([method cast_value]): priced at
	# its printed one, an X spell was the cheapest card in the pool and
	# the fill took four Meteor Showers for a mono-red deck's five-drops
	# (the 2026-09-26 A/B).
	value *= clampf(1.8 / (cast_value(data) + 1.0) + 0.5, 0.7, 1.2)
	value -= _narrowness(data)
	value -= _sacrifice_cost(data)
	return maxf(value, 0.0)


## What a spell's additional sacrifice costs it: a creature or a land is
## a card for a card, and a KIND of permanent — a Goblin, a green
## creature — is one the deck may well not have, so the spell is as dead
## as a colour's hate (the 2026-09-26 A/B built four Goblin Grenades into
## a deck with no Goblin).
static func _sacrifice_cost(data: CardData) -> float:
	if data.additional_sacrifice.is_empty():
		return 0.0
	var what := String(data.additional_sacrifice.get("desc", "")).to_lower()
	if what == "creature" or what == "a creature" or what == "land" or what == "a land":
		return 0.8
	return 1.8


## A card's effects, its own and its activated abilities', the way
## [method AiDeckStudy.classify] gathers them.
static func _spell_effects(data: CardData) -> Array:
	var effects: Array = data.spell_effects.duplicate()
	for ability in data.activated_abilities:
		effects.append_array(ability.effects)
	return effects


## How narrow an answer the card is: a colour's or a land type's hate is
## dead against most decks, an artifact's or an enchantment's is dead
## against some; a creature's is never.
static func _narrowness(data: CardData) -> float:
	var keys := AiSideboard.answers(data)
	if keys.is_empty():
		return 0.0
	for key in keys:
		if BROAD_ANSWERS.has(key):
			return 0.0
	for key in keys:
		if key.begins_with("color:") or key.begins_with("damage:") or key.begins_with("land:"):
			return 1.8
	return 1.0


# ------------------------------------------------------------ the report --

## The notes the deck carries: what was asked, what was chosen and why
## the numbers are what they are.
func _write_report(out: DeckModel, kept: int, kept_lands: int, settled: int) -> void:
	var lean_words := {LEAN_CREATURES: "mostly creatures",
		LEAN_BALANCED: "creatures and spells in balance", LEAN_SPELLS: "mostly spells"}
	report.append("Built by AutoDeck: %d cards, %s, %s speed, %s." % [
		out.total(), color_phrase(cast_colors), speed, String(lean_words[lean])])
	if _splashed != 0:
		report.append("%s chosen, but the lands could not carry the %s the fill took a card or two of; the spells are %s." % [
			color_phrase(_first_choice), color_phrase(_splashed).to_lower().replace("mono-", ""),
			color_phrase(cast_colors).to_lower().replace("mono-", "")])
	elif cast_colors != chosen_colors:
		report.append("%s chosen, but no %s card was worth the lands it wanted; the spells are %s." % [
			color_phrase(chosen_colors), color_phrase(chosen_colors & ~cast_colors).to_lower().replace("mono-", ""),
			color_phrase(cast_colors).to_lower().replace("mono-", "")])
	var thin := _thin_colors(out)
	for color in Mtg.WUBRG:
		if (thin & color) != 0:
			var why := "asked for" if (_required & color) != 0 \
				else ("kept for the gold deck" if gold else "chosen for its cards")
			report.append("%s %s, and light on the lands: %s." % [
				color_phrase(color).replace("Mono-", ""), why, _thin_words(out, color)])
	report.append("Card pool: %s (%d cards on offer)." % [pool_label, pool_total(pool)])
	var lands: Array[String] = []
	var land_count := 0
	var pips := {}
	var curve := [0, 0, 0, 0, 0]
	var creatures := 0
	var spells := 0
	var mana := 0
	for name in out.names():
		var data := DeckModel._card(String(name))
		var copies := int(out.counts[name])
		if data == null:
			continue
		if data.is_land():
			lands.append("%d %s" % [copies, name])
			land_count += copies
			continue
		curve[_bucket(data)] += copies
		spells += copies
		mana += data.cost.mana_value() * copies
		if data.is_creature():
			creatures += copies
		for color in data.cost.colored:
			pips[color] = int(pips.get(color, 0)) + int(data.cost.colored[color]) * copies
	var pip_words: PackedStringArray = []
	for color in Mtg.WUBRG:
		if pips.has(color):
			pip_words.append("%s %d" % [String(Mtg.COLOR_NAMES[color]).to_lower(), int(pips[color])])
	report.append("%d lands: %s%s." % [land_count, ", ".join(lands),
		"" if pip_words.is_empty() else " — pips " + ", ".join(pip_words)])
	report.append("%d spells: %d creatures, %d others; mana values 1: %d, 2: %d, 3: %d, 4: %d, 5+: %d; average %.1f." % [
		spells, creatures, spells - creatures, curve[0], curve[1], curve[2], curve[3], curve[4],
		float(mana) / maxi(spells, 1)])
	if land_total > 0:
		report.append("The land count is the deck's own: %d." % land_total)
	elif spells > 0:
		var cheap := _cheap_mana_or_draw(out)
		report.append("The curve asks for %d lands (Karsten's fit: average mana value %.2f, %d cheap mana or draw spell%s); the %s speed's %d settled at %d." % [
			lands_for(float(mana) / maxi(spells, 1), cheap, size_key()), float(mana) / maxi(spells, 1),
			cheap, "" if cheap == 1 else "s", speed, int(LANDS[size_key()][speed]), settled])
	if variety > 0:
		report.append("Variety %d: the seed's taste moved each card's worth by up to %.2f." % [
			variety, TASTE_SPAN * variety / 100.0])
	if gold:
		var gold_cards := 0
		for name in out.names():
			var data := DeckModel._card(String(name))
			if data != null and is_gold(data):
				gold_cards += int(out.counts[name])
		if gold_cards > 0:
			report.append("A gold deck: multicoloured cards preferred; %d of the %d spells are gold." % [gold_cards, spells])
		else:
			report.append("A gold deck: multicoloured cards preferred, but the pool had none the deck could cast.")
	if power_nine:
		var power: PackedStringArray = []
		for name in POWER_NINE:
			var copies := out.count_of(name)
			if copies > 0:
				power.append(name if copies == 1 else "%d %s" % [copies, name])
		if power.is_empty():
			report.append("The Power Nine asked for, but the pool, the rarity wish and the colours allowed none.")
		else:
			report.append("The Power Nine in play: %s." % ", ".join(power))
	else:
		for name in POWER_NINE:
			if pool.has(name):
				report.append("The Power Nine left out: the switch is off.")
				break
	if rarity != RARITY_ANY:
		report.append("Rarity: %s." % String(RARITY_WORDS[rarity]))
	if land_kind == LANDS_NONCLASSIC:
		report.append("Non-classic lands: %d of the %d lands are not basics." % [land_count - _basics_in(out), land_count])
	if kept > 0:
		report.append("Built around the %d card%s already on the surface%s." % [kept, "" if kept == 1 else "s",
			", %d land%s among them" % [kept_lands, "" if kept_lands == 1 else "s"] if kept_lands > 0 else ""])
	if short_by > 0:
		report.append("The pool ran out after %d spells; %d extra basic land%s fill the deck." % [
			spells, short_by, "" if short_by == 1 else "s"])
	if not tournament:
		report.append("Built without the tournament rules: banned and restricted cards were allowed.")
	report.append("Seed %d: the same pool and wishes build this deck again." % roll)
