class_name SampleHand
extends RefCounted
## [QoL] A SAMPLE HAND from the deck on the table — seven cards off the
## top of a shuffled copy, the Paris mulligan the duel plays, and one
## card a turn after that. The "goldfish" every paper player runs before
## a deck is sleeved: not a statistic but a HAND, looked at, so a build
## whose Draws page says 2-5 lands 80% of the time can also be seen to
## do it — or seen to hold Sengir Vampire, Sengir Vampire, Sengir
## Vampire and a Swamp, which the page never showed.
##
## THE RULES ARE THE DUEL'S, not a new set: the shuffle is the engine's
## own Fisher-Yates ([method MtgGame._shuffle]), the mulligan is the one
## `MtgGame`'s opening block plays since the owner's ruling of 2026-09-08
## — any hand may be thrown back, each redraw ONE CARD FEWER, down to an
## empty hand after the seventh, no bottoming — and the no-land /
## all-land test survives here exactly as it survives there: advice
## ([method is_mulligan_hand]), never a gate. The turns are the first
## player's, who draws no card on turn one, which is the harder case and
## the one a deck is tuned for.
##
## A MODEL AND NOTHING ELSE. Names, not [CardInstance]s: this is the deck
## builder, there is no game, and a proxy has no data at all. The Stats
## window's Hand page ([method DeckBuilderScreen._stats_page_hand]) draws
## what this holds; `tests/unit/test_sample_hand.gd` pins the rules
## without a screen.


## The cards not yet drawn, TOP OF THE LIBRARY LAST so a draw is a
## `pop_back`. Every copy is its own entry — four Swamps are four names.
var library: Array[String] = []

## The hand, in the order it was drawn.
var hand: Array[String] = []

## How many hands have been thrown back since [method new_hand] — the
## engine's `mulligans_taken`, for one seat. The hand is `7 - mulligans`
## cards, or fewer when the deck is smaller than that.
var mulligans := 0

## Which turn it is. One after the deal; [method next_turn] counts it up
## and draws.
var turn := 1

## The deck as a list, one name per copy, in [method DeckModel.names]
## order — so the same seed deals the same hand from the same deck.
var _cards: Array[String] = []

## Its own dice, like [member MtgGame.rng]: a seeded sample is a
## repeatable one, which is what the tests need and what nothing else
## minds.
var _rng := RandomNumberGenerator.new()


## From [param deck]'s MAIN pile — the sideboard is not in the library
## at the opening — with a fresh seed, or [param p_seed] when a caller
## wants the same deal twice. Nothing is dealt yet: [method new_hand].
func _init(deck: DeckModel = null, p_seed := -1) -> void:
	if p_seed >= 0:
		_rng.seed = p_seed
	else:
		_rng.randomize()
	if deck == null:
		return
	for card_name in deck.names():
		for i in int(deck.counts.get(card_name, 0)):
			_cards.append(card_name)


## How many cards the sample deals from — the main deck's total.
func deck_size() -> int:
	return _cards.size()


## Shuffle everything and deal a fresh seven (fewer from a deck smaller
## than seven). Turn one, no mulligans.
func new_hand() -> void:
	mulligans = 0
	_deal(7)


## Throw the hand back and draw one card fewer — the Paris rule as the
## duel plays it. Refused, and false, only when there is no hand left to
## throw back: the seventh mulligan draws nothing, and nothing cannot be
## shuffled away again ([method MtgGame.may_mulligan]).
func mulligan() -> bool:
	if not may_mulligan():
		return false
	mulligans += 1
	_deal(7 - mulligans)
	return true


## Is there a hand to throw back? The engine's own door, minus the seat
## and the keep — a sample has neither.
func may_mulligan() -> bool:
	return not hand.is_empty()


## How many cards the NEXT mulligan would draw — what the button says.
func next_hand_size() -> int:
	return mini(7 - mulligans - 1, _cards.size()) if may_mulligan() else 0


## The next turn: count it, and draw one card if the library has one.
## The name drawn, or "" from an empty library — the sample does not
## lose the game, it only stops drawing.
func next_turn() -> String:
	turn += 1
	if library.is_empty():
		return ""
	var drawn: String = library.pop_back()
	hand.append(drawn)
	return drawn


## How many of the hand are lands, by the registry's word. A proxy has no
## data and counts as a spell — it is what the player stands it in for,
## and the sample cannot know.
func lands_in_hand() -> int:
	var lands := 0
	for card_name in hand:
		if is_land_name(card_name):
			lands += 1
	return lands


## The 1997 rule's hand — no land at all, or nothing but land — as the
## engine names it ([method MtgGame.hand_is_a_mulligan_hand]): the reason
## the announcement gives, never a gate. An empty hand is neither.
func is_mulligan_hand() -> bool:
	if hand.is_empty():
		return false
	var lands := lands_in_hand()
	return lands == 0 or lands == hand.size()


## Cards left to draw.
func library_size() -> int:
	return library.size()


## Whether [param card_name] is a land — the registry's answer, and
## `false` for a name it does not carry (a proxy).
static func is_land_name(card_name: String) -> bool:
	var data := DeckModel._card(card_name)
	return data != null and data.is_land()


## MANY OPENING HANDS, COUNTED: [param runs] fresh sevens of [param deck]
## (each a whole shuffle, as [method new_hand] deals), and what they held.
## The Draws page says what the arithmetic knows; this says what only
## dealing shows — which lands came, whether the hand's lands made the
## colors its spells ask for, whether it had anything to play.
##
## `{runs, hand, lands: [hands with 0..hand lands], average_lands,
## no_land, all_land, keepable (2 to 5), land_names: [{name, hands,
## copies}], colors: [{color, hands}] (a source of each color the deck's
## spells ask for), every_color, creature, turn_one, turn_two (a spell of
## that cost or less, and the lands for it, by count), castable (a spell
## the hand's own lands pay for, by count), average_cost (of the spells
## held), seen: [{name, hands}] (the spells held most often)}`; `hands`
## are counts of [param runs]. {} for an empty deck.
##
## A PROXY IS A CARD IN THE HAND AND NOTHING MORE (campaign 2026-11-26):
## it has no data, so it is no land, no creature and no spell of a known
## cost — it takes its place in the seven and is left out of the plays,
## the average and the spells seen ("the statistics simply skip them",
## [DeckModel]). It used to count as a spell that costs nothing. And a
## real spell that costs nothing (Ornithopter, Black Lotus) is a play with
## no land at all, where it used to wait for one.
static func trials(deck: DeckModel, runs := 1000, p_seed := -1) -> Dictionary:
	var sample := SampleHand.new(deck, p_seed)
	if sample.deck_size() == 0 or runs <= 0:
		return {}
	# What each name is, asked once.
	var facts := {}
	var wanted := {}
	for card_name in deck.names():
		var data := DeckModel._card(card_name)
		var fact := {"land": false, "creature": false, "cost": 0, "makes": [], "known": data != null}
		if data != null:
			fact["land"] = data.is_land()
			fact["creature"] = data.is_creature()
			fact["cost"] = data.cost.mana_value() if data.cost != null and not data.is_land() else 0
			fact["makes"] = MiniCard.mana_colors(data)
			if not data.is_land() and data.cost != null:
				for color in Mtg.WUBRG:
					if (data.cost.color_mask() & color) != 0:
						wanted[color] = true
		facts[card_name] = fact
	var size := mini(7, sample.deck_size())
	var lands: Array[int] = []
	lands.resize(size + 1)
	lands.fill(0)
	var land_hands := {}
	var land_copies := {}
	var color_hands := {}
	for color in wanted:
		color_hands[color] = 0
	var seen := {}
	var out := {"runs": runs, "hand": size, "no_land": 0, "all_land": 0, "keepable": 0, "every_color": 0,
		"creature": 0, "turn_one": 0, "turn_two": 0, "castable": 0}
	var land_total := 0
	var cost_total := 0
	var spell_total := 0
	for run in runs:
		sample._deal(size)
		var n := 0
		var made := {}
		var held := {}
		var creature := false
		var cheapest := 99
		for card_name in sample.hand:
			var fact: Dictionary = facts.get(card_name, {})
			held[card_name] = int(held.get(card_name, 0)) + 1
			for color: int in fact.get("makes", []):
				made[color] = true
			if bool(fact.get("land", false)):
				n += 1
				land_copies[card_name] = int(land_copies.get(card_name, 0)) + 1
			elif bool(fact.get("known", false)):
				creature = creature or bool(fact.get("creature", false))
				cheapest = mini(cheapest, int(fact.get("cost", 0)))
				cost_total += int(fact.get("cost", 0))
				spell_total += 1
		for card_name in held:
			var held_fact: Dictionary = facts.get(card_name, {})
			if bool(held_fact.get("land", false)):
				land_hands[card_name] = int(land_hands.get(card_name, 0)) + 1
			elif bool(held_fact.get("known", false)):
				seen[card_name] = int(seen.get(card_name, 0)) + 1
		lands[n] += 1
		land_total += n
		out["no_land"] += 1 if n == 0 else 0
		out["all_land"] += 1 if n == size else 0
		out["keepable"] += 1 if n >= 2 and n <= 5 else 0
		out["creature"] += 1 if creature else 0
		# A spell that costs nothing needs no land; the rest need theirs.
		out["turn_one"] += 1 if cheapest <= mini(n, 1) else 0
		out["turn_two"] += 1 if cheapest <= mini(n, 2) else 0
		out["castable"] += 1 if cheapest <= n else 0
		var every := true
		for color in color_hands:
			if made.has(color):
				color_hands[color] += 1
			else:
				every = false
		out["every_color"] += 1 if every else 0
	out["lands"] = lands
	out["average_lands"] = float(land_total) / runs
	out["average_cost"] = float(cost_total) / spell_total if spell_total > 0 else 0.0
	var land_rows: Array = []
	for card_name in land_hands:
		land_rows.append({"name": card_name, "hands": int(land_hands[card_name]), "copies": int(land_copies[card_name])})
	land_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["hands"] > b["hands"] if a["hands"] != b["hands"] else String(a["name"]) < String(b["name"]))
	out["land_names"] = land_rows
	var color_rows: Array = []
	for color in Mtg.WUBRG:
		if color_hands.has(color):
			color_rows.append({"color": color, "hands": int(color_hands[color])})
	out["colors"] = color_rows
	var seen_rows: Array = []
	for card_name in seen:
		seen_rows.append({"name": card_name, "hands": int(seen[card_name])})
	seen_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["hands"] > b["hands"] if a["hands"] != b["hands"] else String(a["name"]) < String(b["name"]))
	out["seen"] = seen_rows
	return out


## Shuffle the whole deck and draw [param count] off the top. Turn one.
func _deal(count: int) -> void:
	turn = 1
	library = _cards.duplicate()
	_shuffle(library)
	hand.clear()
	for i in mini(count, library.size()):
		hand.append(library.pop_back())


## [method MtgGame._shuffle], on names.
func _shuffle(cards: Array[String]) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
