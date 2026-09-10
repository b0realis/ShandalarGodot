class_name AiMulligan
extends RefCounted
## THE AI'S MULLIGAN — whether a seat that is not a person throws its
## opening hand back. The owner's playtest, 2026-09-08: *"If you have no
## lands or all lands in hand, the ai or human decision to take mulligan
## is almost automatic - no special rules needed - ok maybe for ai lets
## write some mulliganning logic!"* — and this is that logic.
##
## THE RULE IT SERVES is the Paris mulligan (`MtgGame.take_mulligan`): any
## hand may go back, each redraw is one card fewer, and the question is
## asked again of the smaller hand. So the judgment is not "is this hand
## bad" but "is this hand worse than a random hand one card smaller",
## which is a question about MANA first and COLOURS second and about
## nothing else — the greedy, one-ply shape the rest of `engine/ai/` has.
##
## WHAT IT READS: the hand, and only the hand — the cards' own costs and
## their own mana abilities. Not the library (it is shuffled and
## unknown, and the original does not peek), not the opponent's hand.
##
## THE JUDGMENT, hand of `n` cards with `lands` of them land:
##
## 1. THE FLOOR. A hand of [constant FLOOR] cards or fewer is kept
##    whatever it holds. The hand that would replace it is smaller still,
##    and a four-card hand that draws into its lands beats a three-card
##    one that has to as well.
## 2. THE MANA IT MAKES, against a keep range that narrows with the hand
##    ([constant KEEP_LANDS]): two to five of seven, two to four of six,
##    one to four of five. No mana is no game; nothing but land is no
##    game either, and one land in seven is a gamble the original's own
##    players did not take. Outside the range: throw it back.
##
##    THE FLOOR OF THAT BAND COUNTS MANA AND ITS CEILING COUNTS LANDS,
##    because they are two different questions (2026-09-10, the Forge
##    study's casting note P12). *Can this hand make mana* is
##    [method mana_sources]: the lands, plus every card in it that costs
##    {0} and prints a mana ability — a Mox is a land drop that does not
##    use the land drop up, a Black Lotus is three of them at once, a
##    Mana Crypt is two. *Has this hand anything to spend the mana on* is
##    the lands alone, because a Mox is a spell. Until that split the
##    band read [method land_count] at both ends and a hand of one Island
##    and two Moxen — four mana on turn one, the best keep the format has
##    — went back as "1 land in 7".
##
##    IT ONLY EVER OPENS A KEEP. No hand that was kept before goes back
##    for it, and a deck holding no such card cannot tell the difference.
##    The five shipped starters hold none. SIXTY-NINE of the pool's 217
##    loadable lists do, and nineteen of those are 1997 enemy decks — the
##    ones a player meets in the adventure — which is why this is a
##    correction and not a curiosity.
## 3. THE COLOURS, for a seven or a six inside the range: the hand's mana
##    must be able to CAST at least one of its spells — a spell whose
##    coloured pips the hand's own sources can produce, the generic part
##    ignored (a fourth land is an ordinary draw; a third colour is not).
##    Two Islands under five red cards is no better than no land at all;
##    a Mox Ruby beside them casts the Bolt. Read off
##    `CardData.mana_abilities`, the same list the AI's land drop reads
##    ([method AiPlayer._colour_shortfall]).
##
## Everything else — curve, spell quality, the matchup — is deliberately
## not here. It would be a second evaluator, and the Deck Lab's own
## verdict on this one (docs/ROADMAP.md) is the measure of whether one is
## wanted. Behind [member AiProfile.mulligans]; off, the seat uses the
## plain rule every agent has ([method DecisionAgent.choose_mulligan]),
## which counts lands and nothing else and is untouched by any of this.
##
## WHAT IS NOT HERE, AND WHY (2026-09-10). P12's own escape is Forge's:
## keep a one-lander when the LIBRARY holds fewer than one land in seven
## (`library.size() / landsInDeck > 6`). Measured over every deck this
## pool can load — 217 of them — that test fires on exactly ONE, a
## 40-card list of eighteen Timetwisters, twenty-one Black Lotuses and a
## Fireball; the next sparsest deck in the pool is 3.93 cards per land,
## nowhere near it. And that one deck is fixed by the census above
## without a ratio anywhere: its hands are three or four Lotuses deep.
## So the deck-ratio branch measures nothing here and is not kept — the
## rule this repository holds every AI cut to.

## Kept whatever it holds. The same number, for the same reason, as
## [constant DecisionAgent.MULLIGAN_FLOOR].
const FLOOR := 4

## Per hand size, the inclusive land counts that keep. A size not listed
## is at or under the floor.
const KEEP_LANDS := {
	7: [2, 5],
	6: [2, 4],
	5: [1, 4],
}


## Should [param pid] throw its hand back? The whole judgment above.
static func wants_mulligan(game: MtgGame, pid: int) -> bool:
	return reason(game, pid) != ""


## The judgment with its reason — "" to keep, else why the hand goes back
## (the words the Deck Lab and the tests read; the announcement has its
## own 1997 lines and does not use these).
static func reason(game: MtgGame, pid: int) -> String:
	var hand: Array[CardInstance] = game.players[pid].hand
	var n := hand.size()
	if n <= FLOOR:
		return ""
	var lands := land_count(hand)
	var range: Array = KEEP_LANDS[n]
	if lands < int(range[0]) and mana_sources(hand) < int(range[0]):
		return "no land" if lands == 0 else "%d land in %d" % [lands, n]
	if lands > int(range[1]):
		return "all land" if lands == n else "%d lands in %d" % [lands, n]
	if n >= 6 and not casts_a_spell(hand):
		return "the lands cast none of the spells"
	return ""


static func land_count(hand: Array[CardInstance]) -> int:
	var lands := 0
	for inst in hand:
		if inst.is_land():
			lands += 1
	return lands


## Does [param inst] make mana the turn it is played, for nothing? The
## era's mana that is not a land — a Mox, a Black Lotus, a Mana Crypt:
## a permanent that costs {0} and prints a mana ability, which is a land
## drop that does not use the land drop up.
##
## Named by SHAPE, like every other reading in `engine/ai/`: no card name
## is read here. A Sol Ring is not one of them, because {1} is a mana
## this hand may not have; nor is a land, which [method land_count] has
## already counted.
static func is_free_source(inst: CardInstance) -> bool:
	return not inst.is_land() \
		and inst.data.cost.mana_value() == 0 \
		and not inst.data.mana_abilities.is_empty()


## The mana [param hand] can make on its own — its lands plus its free
## sources. The number the keep band's FLOOR is read against.
static func mana_sources(hand: Array[CardInstance]) -> int:
	var count := land_count(hand)
	for inst in hand:
		if is_free_source(inst):
			count += 1
	return count


## Can the MANA in [param hand] pay the COLOURED part of at least one of
## its spells? Every source is counted for every colour it can make (a
## dual is both, a Black Lotus is all five) and for the amount it makes
## of it (the Lotus's three, which is the {B}{B} a Hypnotic Specter
## wants); the generic part of a cost is ignored.
static func casts_a_spell(hand: Array[CardInstance]) -> bool:
	var have: Dictionary = {}
	for inst in hand:
		if not inst.is_land() and not is_free_source(inst):
			continue
		for ability in inst.data.mana_abilities:
			for pair in ability.produces:
				var color := int(pair[0])
				have[color] = int(have.get(color, 0)) + int(pair[1])
	for inst in hand:
		if inst.is_land():
			continue
		var fits := true
		for color in inst.data.cost.colored:
			if color == Mtg.ManaColor.C:
				continue
			if int(have.get(int(color), 0)) < int(inst.data.cost.colored[color]):
				fits = false
				break
		if fits:
			return true
	return false
