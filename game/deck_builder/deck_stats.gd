class_name DeckStats
## `[QoL]` The numbers a deck builder actually wants, computed exactly.
##
## The 1997 Stats window is a Card Type x colour MATRIX. It answers *what
## is in here* and cannot answer *is this going to work* — which is the
## question a player is really asking when they open it. [DeckModel]
## already carries the shape of the deck (the matrix, the curve, the
## colour counts, the mana sources); this adds the part that needs
## probability.
##
## **EXACT, NOT SIMULATED.** Every draw question here is a hypergeometric
## — drawing without replacement from a known deck — and the closed form
## is both faster and *right*, where a Monte Carlo would give a slightly
## different answer every time it was opened. A player comparing two land
## counts needs the second number to differ because the deck differs, not
## because the dice did.
##
## All of it is pure and static: the window is a view, and the tests read
## the numbers rather than the pixels (`tests/ui/test_deck_stats.gd`).

## The opening hand. Seven in every format this pool was played in, and
## the number every probability below is anchored to.
const HAND := 7

## How deep the "by turn N" questions look. Turn 5 is where a 1997 deck
## has usually decided the game; past that the numbers stop informing a
## build decision.
const HORIZON := 5


# ------------------------------------------------------- the exact core --

## P(exactly [param k] of [param successes] in [param draws] from a deck
## of [param pop]) — the hypergeometric probability mass.
##
## COMPUTED AS A PRODUCT OF RATIOS, never as three factorials divided:
## `C(250, 7)` overflows a 64-bit int, and a deck of 250 is a legal thing
## for a player to build here. Multiplying and dividing alternately keeps
## every partial product near 1.0, so the answer is accurate for any deck
## a person can assemble.
static func hypergeometric(pop: int, successes: int, draws: int, k: int) -> float:
	if pop <= 0 or draws < 0 or draws > pop:
		return 0.0
	if k < 0 or k > draws or k > successes or (draws - k) > (pop - successes):
		return 0.0
	# C(successes,k) * C(pop-successes,draws-k) / C(pop,draws), as one
	# alternating product.
	var result := 1.0
	for i in range(k):
		result *= float(successes - i) / float(i + 1)
	for i in range(draws - k):
		result *= float(pop - successes - i) / float(i + 1)
	for i in range(draws):
		result *= float(draws - i) / float(pop - i)
	return result


## P(at least [param k]) — the upper tail, summed from the exact mass.
static func at_least(pop: int, successes: int, draws: int, k: int) -> float:
	var total := 0.0
	for i in range(k, draws + 1):
		total += hypergeometric(pop, successes, draws, i)
	return total


# -------------------------------------------------------- opening hands --

## P(exactly n lands in the opening seven), indexed by n.
##
## The single most useful row in this window: it is the difference
## between a deck that keeps its hands and one that mulligans, and it is
## the number people guess at rather than compute.
static func land_odds(deck: DeckModel, hand := HAND) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var pop := deck.total()
	var lands := deck.land_count()
	for k in range(hand + 1):
		out.append(hypergeometric(pop, lands, mini(hand, pop), k))
	return out


## P(the opening seven holds between [param lo] and [param hi] lands) —
## a keepable hand.
##
## TWO TO FIVE is the band, and it is a judgement this window states
## rather than hides: one land is a hand that usually cannot function and
## six is a hand that has nothing to cast. A player who disagrees can read
## the exact row above; this is the one-number summary.
static func keepable(deck: DeckModel, lo := 2, hi := 5, hand := HAND) -> float:
	var odds := land_odds(deck, hand)
	var total := 0.0
	for k in range(lo, mini(hi, odds.size() - 1) + 1):
		total += odds[k]
	return total


## P(having made every land drop through turn [param turn]) — i.e. that
## at least [param turn] lands are among the cards seen by then.
##
## ON THE PLAY you have seen `7 + turn - 1`; on the draw, one more. The
## distinction is not pedantry: it is a whole card, and it moves the
## turn-4 number by several points in a lean deck.
static func land_drop_odds(deck: DeckModel, turn: int, on_play := true) -> float:
	var seen := HAND + turn - (1 if on_play else 0)
	return at_least(deck.total(), deck.land_count(),
		mini(seen, deck.total()), turn)


# ------------------------------------------------------ colour and mana --

## Coloured mana SYMBOLS in the deck's costs, by `Mtg.ManaColor`.
##
## Pips, not cards: `{B}{B}{B}` asks three times as much of the mana base
## as `{B}` does, and a deck whose colour counts look balanced can still
## be unable to cast the thing it is built around. This is the number
## that says how hard a colour is being leaned on.
static func color_pips(deck: DeckModel) -> Dictionary:
	var pips := {}
	for card_name in deck.counts:
		var d := deck._card(card_name)
		if d == null or d.cost == null:
			continue
		var have := int(deck.counts[card_name])
		for color in d.cost.colored:
			pips[color] = int(pips.get(color, 0)) + int(d.cost.colored[color]) * have
	return pips


## P(at least one source of [param color] among the cards seen by
## [param turn]) — "will I have the colour when I need it".
static func color_by_turn(deck: DeckModel, color: int, turn: int,
		on_play := true) -> float:
	var sources := deck.mana_sources()
	var have := int(sources.get(color, 0))
	var seen := HAND + turn - (1 if on_play else 0)
	return at_least(deck.total(), have, mini(seen, deck.total()), 1)


## The deck's hardest cast: the card with the most pips of one colour,
## and the turn by which its colour is reliably (>=90%) available.
## `{}` when the deck asks for no coloured mana at all.
static func hardest_cast(deck: DeckModel) -> Dictionary:
	var worst_name := ""
	var worst_pips := 0
	var worst_color := -1
	for card_name in deck.counts:
		var d := deck._card(card_name)
		if d == null or d.cost == null:
			continue
		for color in d.cost.colored:
			var n := int(d.cost.colored[color])
			if n > worst_pips:
				worst_pips = n
				worst_name = card_name
				worst_color = int(color)
	if worst_name == "":
		return {}
	return {"card": worst_name, "pips": worst_pips, "color": worst_color,
		"cost": deck._card(worst_name).cost.mana_value()}


# ------------------------------------------------------------- the speed --

## How fast the deck acts, as the numbers that decide it.
##
## `creature_cost` and `spell_cost` are kept APART because they answer
## different questions — how soon the board starts, and how soon the deck
## can answer something — and averaging them together hides both.
static func speed(deck: DeckModel) -> Dictionary:
	var creature_total := 0
	var creatures := 0
	var other_total := 0
	var others := 0
	var power := 0
	var cheapest := 99
	for card_name in deck.counts:
		var d := deck._card(card_name)
		if d == null or d.is_land():
			continue
		var have := int(deck.counts[card_name])
		var mv := d.cost.mana_value() if d.cost != null else 0
		if d.types & Mtg.CardType.CREATURE:
			creatures += have
			creature_total += mv * have
			power += d.power * have
			cheapest = mini(cheapest, mv)
		else:
			others += have
			other_total += mv * have
	return {
		"creature_cost": 0.0 if creatures == 0
			else float(creature_total) / float(creatures),
		"spell_cost": 0.0 if others == 0
			else float(other_total) / float(others),
		"creatures": creatures,
		"average_power": 0.0 if creatures == 0
			else float(power) / float(creatures),
		"cheapest_creature": 0 if cheapest == 99 else cheapest,
	}


## P(a creature castable by turn [param turn] is in hand by then) —
## the deck's opening speed, which is what "is this deck fast" means in
## practice. Counts only creatures whose mana value is at most the turn,
## and assumes the land drops were made (`land_drop_odds` is the other
## half of that question and is reported beside this one).
static func creature_by_turn(deck: DeckModel, turn: int,
		on_play := true) -> float:
	var castable := 0
	for card_name in deck.counts:
		var d := deck._card(card_name)
		if d == null or d.is_land() or not (d.types & Mtg.CardType.CREATURE):
			continue
		if d.cost != null and d.cost.mana_value() <= turn:
			castable += int(deck.counts[card_name])
	var seen := HAND + turn - (1 if on_play else 0)
	return at_least(deck.total(), castable, mini(seen, deck.total()), 1)


# ------------------------------------------------ what the deck fights --

## The colour words a card's rules text names, as a `Mtg.ManaColor` array.
##
## THE 1997 POOL IS FULL OF COLOUR HATE — Karma, Gloom, Lifeforce,
## Deathgrip, Conversion, the Elemental Blasts, the Circles of Protection
## — and which colours a deck can punish (and be punished by) is a real
## build decision in a game whose opponents have known colours. Detected
## from the ORACLE TEXT rather than from a hand-written list, so a card
## added to the pool later is covered without anyone remembering to.
static func colors_named(data: CardData) -> Array[int]:
	var found: Array[int] = []
	if data == null or data.oracle_text == "":
		return found
	var text := data.oracle_text.to_lower()
	# BOTH VOCABULARIES, because the era used the second one more.
	# "Karma deals damage equal to the number of SWAMPS they control" is
	# the most famous black-hate card in the pool and the word "black"
	# never appears on it; the same is true of Lifeforce, Conversion and
	# every landwalker. Naming a basic land IS naming a colour here, and a
	# detector that only read colour words found Karma innocent (caught by
	# the test, 2026-09-05).
	for pair in [["white", Mtg.ManaColor.W], ["plains", Mtg.ManaColor.W],
			["blue", Mtg.ManaColor.U], ["island", Mtg.ManaColor.U],
			["black", Mtg.ManaColor.B], ["swamp", Mtg.ManaColor.B],
			["red", Mtg.ManaColor.R], ["mountain", Mtg.ManaColor.R],
			["green", Mtg.ManaColor.G], ["forest", Mtg.ManaColor.G]]:
		var color := int(pair[1])
		if text.contains(String(pair[0])) and not found.has(color):
			found.append(color)
	return found


## Cards in the deck that name a colour, with the colours they name:
## `[{"card": "Karma", "count": 2, "colors": [B]}, ...]`.
static func color_hate(deck: DeckModel) -> Array:
	var out := []
	for card_name in deck.counts:
		var d := deck._card(card_name)
		var named := colors_named(d)
		if named.is_empty():
			continue
		out.append({"card": card_name, "count": int(deck.counts[card_name]),
			"colors": named})
	out.sort_custom(func(a, b): return String(a["card"]) < String(b["card"]))
	return out


## Cards that play for the ANTE, which in this game is not a curiosity:
## Shandalar duels are played for a card and these change what a loss
## costs. Detected from the oracle text, which names the ante explicitly
## on every card in the pool that touches it.
static func ante_cards(deck: DeckModel) -> Array:
	var out := []
	for card_name in deck.counts:
		var d := deck._card(card_name)
		if d == null or not d.oracle_text.to_lower().contains("ante"):
			continue
		out.append({"card": card_name, "count": int(deck.counts[card_name])})
	out.sort_custom(func(a, b): return String(a["card"]) < String(b["card"]))
	return out


## Creatures the defender has trouble stopping, by the keyword that makes
## them hard to block. A deck's real clock is its EVASION, not its power:
## twelve points of ground beef into a wall is nothing.
static func evasion(deck: DeckModel) -> Dictionary:
	var tally := {}
	for card_name in deck.counts:
		var d := deck._card(card_name)
		if d == null or not (d.types & Mtg.CardType.CREATURE):
			continue
		var have := int(deck.counts[card_name])
		for key in d.keywords:
			if key in [Mtg.Keyword.FLYING, Mtg.Keyword.TRAMPLE,
					Mtg.Keyword.FEAR]:
				tally[int(key)] = int(tally.get(int(key), 0)) + have
		if not d.landwalk.is_empty():
			tally["landwalk"] = int(tally.get("landwalk", 0)) + have
		if not d.cant_be_blocked_by.is_empty():
			tally["unblockable"] = int(tally.get("unblockable", 0)) + have
	return tally


# ------------------------------------------------------------- rarity --

## RARITY, WHICH THE CARD OBJECTS DO NOT CARRY. `cards/data/*.json` has a
## `rarity` for every printing and ships inside the `.pck`, but [CardData]
## has no field for it and the 897 card files are hand-written — putting a
## rarity line in each of them to surface one statistic would be the tail
## wagging the dog. So it is read from the data, once, and kept by name.
##
## It matters more here than in a constructed format: this is Shandalar,
## where a rare is something you have to go and WIN, and a deck leaning on
## four of them is a deck you cannot yet build.
static var _rarity: Dictionary = {}


## The rarity of a card by name — `"common"`, `"uncommon"`, `"rare"`,
## `"special"`, or `""` when the pool's data does not say.
static func rarity_of(card_name: String) -> String:
	if _rarity.is_empty():
		_load_rarity()
	return String(_rarity.get(card_name, ""))


## First printing wins, which matches how the rest of this project treats
## a card that appears in several sets ([method DeckStats.rarity_counts]
## is about the deck, not about a particular printing).
static func _load_rarity() -> void:
	var dir := DirAccess.open("res://cards/data")
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string("res://cards/data/" + file_name)
		if text == "":
			continue
		var parsed: Variant = JSON.parse_string(text)
		if not (parsed is Array):
			continue
		for entry in parsed:
			if not (entry is Dictionary):
				continue
			var name := String(entry.get("name", ""))
			if name != "" and not _rarity.has(name):
				_rarity[name] = String(entry.get("rarity", ""))


## How many cards of each rarity the deck holds, plus `"unknown"` for any
## the data does not cover.
static func rarity_counts(deck: DeckModel) -> Dictionary:
	var tally := {}
	for card_name in deck.counts:
		var rarity := rarity_of(card_name)
		if rarity == "":
			rarity = "unknown"
		tally[rarity] = int(tally.get(rarity, 0)) + int(deck.counts[card_name])
	return tally
