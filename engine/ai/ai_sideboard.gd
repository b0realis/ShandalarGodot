class_name AiSideboard
extends RefCounted
## AI SIDEBOARDING — `Side&board between duels` (`Program/Text.res:2863`)
## for a seat that is not a person. M4 phase 2.x, designed in
## `docs/ROADMAP.md` and built to that design.
##
## THE GAP THIS CLOSES. Everything around the between-duels step was
## already built — [DeckList] parses and round-trips `SB:`,
## [DuelConfig.sideboards] carries both piles, [MatchState] carries the
## checkbox and [MatchScreen] has the window — and the step was offered to
## HUMAN seats only, because the AI had no way to use it. A best-of-N
## against the AI was therefore a match in which one side adapted and the
## other did not.
##
## WHAT IT IS ALLOWED TO KNOW: [AiMatchMemory] and nothing else. Not the
## opponent's decklist — reading it would be cheating and the original does
## not cheat here. What it saw cast, played or put onto the battlefield,
## and which colours have burned it. That is the real signal in paper
## Magic and it is the one used here.
##
## THE HEURISTIC, in the shape the rest of `engine/ai/` uses (greedy, one
## ply, no search):
##
## 1. Turn the memory into a TALLY of the things a sideboard card can
##    answer — artifacts, enchantments, creatures, flyers, graveyard
##    recursion, each colour, each basic land type, and damage taken per
##    colour ([method tallies]).
## 2. Read each candidate's ANSWER PROFILE off its oracle text
##    ([method answers]) — the set of tally keys it addresses. A card with
##    no answer verb (a Serra Angel) has no profile and is judged on
##    generic quality alone.
## 3. Score every card in both piles on the same scale ([method score]):
##    a damped generic value plus the matchup bonus, minus a penalty for a
##    narrow answer with NOTHING to answer — which is what makes a
##    maindeck Blue Elemental Blast against a green deck the first card
##    cut.
## 4. Swap the best IN for the worst OUT, strictly one for one, up to
##    [member AiProfile.sideboard_swaps], never cutting a land, and never
##    boarding in a card the deck's own mana cannot cast.
##
## THREE INVARIANTS, each pinned by a test in `tests/ai/test_ai_sideboard.gd`:
## the deck's SIZE never moves (the swap is one for one); the copy limit is
## counted ACROSS BOTH PILES (four in the deck plus one in the board is
## five copies and illegal) — which holds structurally, because moving a
## card between the piles leaves their union untouched, and is re-checked
## against [DeckFormat] anyway; and a match that started in a FORMAT is
## still legal at duel 2.
##
## DIFFICULTY is the existing model and no other: [AiProfile]'s
## `sideboard_swaps` says how many cards a profile may move (the Apprentice
## moves none — sorcery-speed "my turn only" Magic is that profile's whole
## feel), and `mistake_chance` fumbles individual swaps exactly as it
## fumbles a cast or an attack.
##
## DETERMINISM. Every choice is a pure function of (the memory, the two
## piles, the profile) plus rolls taken from the [MtgGame.rng] of the duel
## that just ended — CONTRIBUTING.md rule 7. Ties break on card NAME, because
## `Array.sort_custom` is not a stable sort and an unbroken tie would make
## a seeded match replay differently on a different day.
##
## WHAT IS DELIBERATELY NOT MEASURED: how little a maindeck card actually
## DID in the duels played. A card that never left the library did nothing
## and that is not the card's fault, so per-card performance is mostly
## noise at this sample size; "how little it can do in THIS matchup" is the
## question asked instead, and it is answered from the same tally.

# ------------------------------------------------------------ the tally --

## Tally keys with a fixed spelling. Colours, basic land types and damage
## build their keys as `color:red`, `land:swamp`, `damage:red` — the
## PREFIX before the colon is what [constant SIGNAL_WEIGHT] is keyed on.
const S_ARTIFACT := "artifact"
const S_ENCHANTMENT := "enchantment"
const S_CREATURE := "creature"
const S_FLYING := "flying"
const S_GRAVEYARD := "graveyard"

## What one point of each signal is worth, in the same "stat points"
## currency [Evaluator] uses. `creature` is the cheapest because nearly
## every deck is full of creatures, so it discriminates least; artifact,
## enchantment and graveyard hate are the expensive ones because a deck
## that shows none of them makes those cards worthless.
const SIGNAL_WEIGHT := {
	S_ARTIFACT: 0.7, S_ENCHANTMENT: 0.7, S_GRAVEYARD: 0.7,
	S_FLYING: 0.6, S_CREATURE: 0.25,
	"color": 0.45, "land": 0.5, "damage": 0.35,
}

## No signal counts past this. The fourth Shatter against eight artifacts
## is not twice the card the fourth against four is, and without a cap one
## lopsided tally would swamp every other consideration.
const SIGNAL_CAP := 8

## How much of [method Evaluator.card_value] survives into the score.
## Damped hard on purpose: sideboarding is about the MATCHUP, and at full
## weight the heuristic degenerates into "board in the biggest creature".
const BASE_WEIGHT := 0.35

## Penalty for a card that answers something the opponent has none of — a
## Tranquility against a deck with no enchantments. Big enough that a dead
## narrow answer is always cut before a merely mediocre card.
const DEAD_CARD := 3.0

## How much better a sideboard card must be than the card it replaces.
## Without a margin, a rounding difference between two comparable cards
## would spend a swap and change a deck for nothing.
const SWAP_MARGIN := 1.0

## Words that make a card an ANSWER rather than a card that merely mentions
## something. "Target creature gets +3/+3" names a creature and answers
## nothing; "Destroy all creatures" names the same word and answers plenty.
const ANSWER_VERBS: Array[String] = [
	"destroy", "counter target", "counter all", "exile", "bury",
	"prevent", "damage", "sacrifice", "can't", "cost {", "cost more",
	"return target", "tap target", "-1/-1", "-2/-2", "loses",
]

## Basic land types, as the oracle text spells them. Keyed to
## [constant Mtg.BASIC_LAND_COLORS] so the two lists cannot drift.
const LAND_WORDS: Array[String] = ["plains", "island", "swamp", "mountain",
	"forest"]


## The tally the heuristic scores against: signal key -> how much of it the
## opponent has shown. Derived, not stored, so [AiMatchMemory] stays a
## record of observations and this file owns every judgement.
##
## Read off the PRINTED [CardData] of each name seen, which is the right
## source here and not a CONTRIBUTING.md rule-5 violation: the question is what
## is in the opponent's DECK, and a deck holds printed cards. (Rule 5 is
## about a permanent on the battlefield, whose characteristics can change;
## the one live reading this heuristic needs — the colour a source dealt
## damage as — is taken at the moment of the damage, in [AiMatchMemory].)
static func tallies(memory: AiMatchMemory) -> Dictionary:
	var tally := {}
	for card_name in memory.seen:
		var data := CardRegistry.get_card(String(card_name))
		if data == null:
			continue
		var copies: int = memory.seen[card_name]
		if data.is_type(Mtg.CardType.ARTIFACT):
			_add(tally, S_ARTIFACT, copies)
		if data.is_type(Mtg.CardType.ENCHANTMENT):
			_add(tally, S_ENCHANTMENT, copies)
		if data.is_creature():
			_add(tally, S_CREATURE, copies)
			if data.has_keyword(Mtg.Keyword.FLYING):
				_add(tally, S_FLYING, copies)
		for color in Mtg.COLOR_NAMES:
			if color != Mtg.ManaColor.C and (data.color_mask() & color):
				_add(tally, "color:" + String(Mtg.COLOR_NAMES[color]).to_lower(),
					copies)
		for subtype in data.subtypes:
			var folded := String(subtype).to_lower()
			if LAND_WORDS.has(folded):
				_add(tally, "land:" + folded, copies)
		# RECURSION, the graveyard-hate signal: a deck that keeps buying
		# its dead back is a deck a Tormod's Crypt answers.
		if data.oracle_text.to_lower().contains("graveyard"):
			_add(tally, S_GRAVEYARD, copies)
	for color in memory.damage_by_color:
		if color == Mtg.ManaColor.C:
			continue
		_add(tally, "damage:" + String(Mtg.COLOR_NAMES[color]).to_lower(),
			int(memory.damage_by_color[color]))
	return tally


static func _add(tally: Dictionary, key: String, amount: int) -> void:
	tally[key] = int(tally.get(key, 0)) + amount


# --------------------------------------------------------- answer profile --

## The tally keys [param data] addresses, or [] when it answers nothing.
##
## Read off the ORACLE TEXT, which is the printed card. There is no tag
## database in this project and writing one for 897 cards to serve one
## heuristic would be a second source of truth to keep in step; the oracle
## line already says what the card does, in the words the card says it in.
##
## Two normalisations do the heavy lifting, and both matter:
## `nonartifact, nonblack creature` (Terror) must not read as artifact hate
## or black hate, and `each creature without flying` (Earthquake) must not
## read as flying hate. Every `non<word>` and `without <word>` is deleted
## before anything is matched.
static func answers(data: CardData) -> Array[String]:
	var text := data.oracle_text.to_lower()
	if text.is_empty():
		return []
	text = _strip_negations(text)
	var is_answer := false
	for verb in ANSWER_VERBS:
		if text.contains(verb):
			is_answer = true
			break
	if not is_answer:
		return []
	var keys: Array[String] = []
	if text.contains("artifact"):
		keys.append(S_ARTIFACT)
	if text.contains("enchantment"):
		keys.append(S_ENCHANTMENT)
	if text.contains("creature"):
		keys.append(S_CREATURE)
	if text.contains("flying"):
		keys.append(S_FLYING)
	if text.contains("graveyard"):
		keys.append(S_GRAVEYARD)
	for color in Mtg.COLOR_NAMES:
		if color == Mtg.ManaColor.C:
			continue
		var word := String(Mtg.COLOR_NAMES[color]).to_lower()
		if not text.contains(word):
			continue
		keys.append("color:" + word)
		# A PREVENTION card answers the colour that HURT, which is a
		# different tally from the colour the opponent's cards are: a
		# Circle of Protection: Red against a red deck full of creatures
		# it never gets to block is worth less than against a burn deck.
		if text.contains("prevent"):
			keys.append("damage:" + word)
	for land in LAND_WORDS:
		if text.contains(land):
			keys.append("land:" + land)
	return keys


## Delete `non<word>` and `without <word>` — see [method answers]. Matched
## at a WORD BOUNDARY only: a naive substring search for "non" also eats
## the middle of "cannon" and leaves a text nobody wrote.
static func _strip_negations(text: String) -> String:
	var out := text
	var prefixes: Array[String] = ["non", "without "]
	for prefix in prefixes:
		var from := 0
		while true:
			var at := out.find(prefix, from)
			if at == -1:
				break
			if at > 0 and out[at - 1] >= "a" and out[at - 1] <= "z":
				from = at + 1
				continue
			var end := at + prefix.length()
			while end < out.length() and out[end] >= "a" and out[end] <= "z":
				end += 1
			out = out.substr(0, at) + " " + out.substr(end)
			from = at + 1
	return out


## What one card is worth to this deck in THIS matchup, on one scale for
## both piles so that "the best card in the board beats the worst card in
## the deck" is a question that can be asked at all.
static func score(data: CardData, tally: Dictionary) -> float:
	var value := Evaluator.card_value(data) * BASE_WEIGHT
	var keys := answers(data)
	if keys.is_empty():
		return value
	var bonus := 0.0
	var matched := false
	for key in keys:
		var count := mini(int(tally.get(key, 0)), SIGNAL_CAP)
		if count <= 0:
			continue
		matched = true
		var weight: float = SIGNAL_WEIGHT.get(key,
			SIGNAL_WEIGHT.get(key.get_slice(":", 0), 0.0))
		bonus += count * weight
	if not matched:
		return value - DEAD_CARD
	return value + bonus


# ------------------------------------------------------------- the swap --

## Sideboard [param deck] against what [param memory] saw, moving cards to
## and from [param board]. BOTH ARRAYS ARE MUTATED IN PLACE — they are the
## caller's own piles ([DuelConfig.decks] / [DuelConfig.sideboards]), and
## the between-duels step exists precisely to edit them.
##
## Returns `{"in": [names], "out": [names]}`, index-matched, so a caller
## can log or show exactly what moved. An empty plan means nothing moved
## and both piles are untouched.
##
## [param format] is one of [DeckFormat]'s; when it is set, the result is
## re-checked and the whole plan REVERTED if it would not be legal. One for
## one swaps between two piles cannot break a format (legality is a
## function of the union of the piles, which the swap leaves alone), so
## this guard should never fire — it is here because "should never" is the
## kind of claim that wants a check behind it, and because the invariant
## belongs at the place a future non-one-for-one swap would break it.
static func sideboard(memory: AiMatchMemory, deck: Array, board: Array,
		profile: AiProfile, rng: RandomNumberGenerator,
		format := DeckFormat.UNRESTRICTED) -> Dictionary:
	var empty := {"in": [], "out": []}
	if profile == null or profile.sideboard_swaps <= 0:
		return empty
	if board.is_empty() or deck.is_empty() or memory.duels <= 0:
		return empty
	var tally := tallies(memory)
	var colors := deck_colors(deck)
	var in_pool := _pool(board, tally, false, colors)
	var out_pool := _pool(deck, tally, true, colors)
	if in_pool.is_empty() or out_pool.is_empty():
		return empty

	var before_deck := deck.duplicate()
	var before_board := board.duplicate()
	var moved_in: Array[String] = []
	var moved_out: Array[String] = []
	var in_at := 0
	var out_at := 0
	while moved_in.size() < profile.sideboard_swaps:
		if in_at >= in_pool.size() or out_at >= out_pool.size():
			break
		var coming: Dictionary = in_pool[in_at]
		var going: Dictionary = out_pool[out_at]
		if coming["score"] - going["score"] < SWAP_MARGIN:
			break
		# THE FUMBLE, in the one model this project has for difficulty: the
		# swap is understood and then simply not made. Rolled before the
		# pools advance so that a fumbled swap costs the profile the slot,
		# the way a fumbled attack costs it the attacker.
		var fumbled := profile.mistake_chance > 0.0 \
			and rng.randf() < profile.mistake_chance
		if not fumbled:
			board.remove_at(board.find(coming["name"]))
			deck.append(coming["name"])
			deck.remove_at(deck.find(going["name"]))
			board.append(going["name"])
			moved_in.append(String(coming["name"]))
			moved_out.append(String(going["name"]))
		coming["left"] = int(coming["left"]) - 1
		going["left"] = int(going["left"]) - 1
		if int(coming["left"]) <= 0:
			in_at += 1
		if int(going["left"]) <= 0:
			out_at += 1
	if moved_in.is_empty():
		return empty
	if format != DeckFormat.UNRESTRICTED \
			and DeckFormat.legal(deck, format, board) != "":
		deck.assign(before_deck)
		board.assign(before_board)
		return empty
	return {"in": moved_in, "out": moved_out}


## One pile as swap candidates: one entry per distinct card name, with the
## copies available and this matchup's score, sorted so that entry 0 is the
## one to move first. Ties break on NAME — `sort_custom` is not stable, and
## an unbroken tie is a seeded match that replays differently.
##
## [param cutting] builds the OUT side, which drops LANDS: a sideboard plan
## that quietly takes the deck from seventeen lands to fourteen is a plan
## that loses the next duel to a mulligan, and no 1997 or modern sideboard
## guide cuts mana to fit hate. [param colors] refuses, on the IN side, a
## card whose coloured pips the deck's own mana cannot produce.
static func _pool(pile: Array, tally: Dictionary, cutting: bool,
		colors: int) -> Array:
	var counts := {}
	for card_name in pile:
		counts[card_name] = int(counts.get(card_name, 0)) + 1
	var out: Array = []
	for card_name in counts:
		var data := CardRegistry.get_card(String(card_name))
		if data == null:
			continue
		if cutting and data.is_land():
			continue
		if not cutting and colors != 0 \
				and (data.cost.color_mask() & ~colors) != 0:
			continue
		out.append({"name": String(card_name), "left": int(counts[card_name]),
			"score": score(data, tally)})
	out.sort_custom(_worst_first if cutting else _best_first)
	return out


static func _best_first(a: Dictionary, b: Dictionary) -> bool:
	if a["score"] == b["score"]:
		return String(a["name"]) < String(b["name"])
	return a["score"] > b["score"]


static func _worst_first(a: Dictionary, b: Dictionary) -> bool:
	if a["score"] == b["score"]:
		return String(a["name"]) < String(b["name"])
	return a["score"] < b["score"]


## The colours [param deck]'s own mana sources can produce, as an
## Mtg.ManaColor mask. A deck that produces nothing at all (a test fixture,
## a deck of nothing but spells) returns 0, which [method _pool] reads as
## "no opinion" rather than "cast nothing" — refusing to sideboard because
## a deck is already unplayable would be an arbitrary place to stop.
static func deck_colors(deck: Array) -> int:
	var mask := 0
	for card_name in deck:
		var data := CardRegistry.get_card(String(card_name))
		if data == null:
			continue
		for ability in data.mana_abilities:
			# "Add one mana of any color" (Birds of Paradise, Celestial
			# Prism) covers everything, and is the whole reason a deck
			# with one Bird may board in an off-colour answer.
			if ability.color_options.is_valid() or ability.dynamic_color.is_valid():
				return Mtg.ManaColor.W | Mtg.ManaColor.U | Mtg.ManaColor.B \
					| Mtg.ManaColor.R | Mtg.ManaColor.G
			for pair in ability.produces:
				mask |= int(pair[0])
	return mask


## The plan as one log line — "sideboarded in Shatter, Shatter; out Gloom,
## Gloom". "" for an empty plan, so a caller can print it unconditionally.
static func summary(plan: Dictionary) -> String:
	var coming: Array = plan.get("in", [])
	if coming.is_empty():
		return ""
	return "sideboarded in %s; out %s" % [", ".join(coming),
		", ".join(plan.get("out", []))]
