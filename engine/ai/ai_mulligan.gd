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
## which is a question about LANDS first and COLOURS second and about
## nothing else — the greedy, one-ply shape the rest of `engine/ai/` has.
##
## WHAT IT READS: the hand, and only the hand — the cards' own costs and
## the lands' own mana abilities. Not the library (it is shuffled and
## unknown, and the original does not peek), not the opponent's hand.
##
## THE JUDGMENT, hand of `n` cards with `lands` of them land:
##
## 1. THE FLOOR. A hand of [constant FLOOR] cards or fewer is kept
##    whatever it holds. The hand that would replace it is smaller still,
##    and a four-card hand that draws into its lands beats a three-card
##    one that has to as well.
## 2. THE LAND COUNT, against a keep range that narrows with the hand
##    ([constant KEEP_LANDS]): two to five of seven, two to four of six,
##    one to four of five. No land is no game; nothing but land is no
##    game either, and one land in seven is a gamble the original's own
##    players did not take. Outside the range: throw it back.
## 3. THE COLOURS, for a seven or a six inside the range: the lands must
##    be able to CAST at least one of the hand's spells — a spell whose
##    coloured pips the hand's lands can produce, the generic part
##    ignored (a fourth land is an ordinary draw; a third colour is not).
##    Two Islands under five red cards is no better than no land at all.
##    Read off `CardData.mana_abilities`, the same list the AI's land drop
##    reads ([method AiPlayer._colour_shortfall]).
##
## Everything else — curve, spell quality, the matchup — is deliberately
## not here. It would be a second evaluator, and the Deck Lab's own
## verdict on this one (docs/ROADMAP.md) is the measure of whether one is
## wanted. Behind [member AiProfile.mulligans]; off, the seat uses the
## plain rule every agent has ([method DecisionAgent.choose_mulligan]).

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
	if lands < int(range[0]):
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


## Can the lands in [param hand] pay the COLOURED part of at least one of
## its spells? Each land is counted once, for every colour it can make
## (a dual is both); the generic part of a cost is ignored.
static func casts_a_spell(hand: Array[CardInstance]) -> bool:
	var have: Dictionary = {}
	for inst in hand:
		if not inst.is_land():
			continue
		for ability in inst.data.mana_abilities:
			for pair in ability.produces:
				var color := int(pair[0])
				have[color] = int(have.get(color, 0)) + 1
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
