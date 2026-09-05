class_name Evaluator
extends RefCounted
## Position and card evaluation — the AI's sense of what things are worth.
## Pure static functions over game state; no mutation, no randomness.
##
## Modeled on mage-go's eval package (a weighted position score the
## Adaptive strategy consults) at GDScript scale. Every weight is a named
## constant so tuning is legible; when profiles need to scale these,
## thread an AiProfile through rather than editing constants.

## Keyword worth, in "stat points" (a 2/2 flyer ≈ a 3/2 ground creature).
const KEYWORD_VALUE := {
	Mtg.Keyword.FLYING: 1.5,
	Mtg.Keyword.FIRST_STRIKE: 1.0,
	Mtg.Keyword.TRAMPLE: 1.0,
	Mtg.Keyword.VIGILANCE: 0.5,
	Mtg.Keyword.REACH: 0.4,
	Mtg.Keyword.BANDING: 0.3,
	Mtg.Keyword.MUST_ATTACK: -0.5,   # a drawback
	Mtg.Keyword.DEFENDER: -1.0,      # can't attack
}

# Position-score weights, in the same "stat points" currency as
# KEYWORD_VALUE — one point of life is the unit everything else is priced
# against.

## Weight of a life-total lead. The cheapest resource, so the lowest weight.
const W_LIFE := 1.0

## Weight of a non-land board lead. Doubled because board presence both
## threatens and defends, and because [method permanent_value] is already a
## conservative number.
const W_BOARD := 2.0

## Weight of a hand-size lead — cards in hand are unrealised board.
const W_HAND := 1.5

## Weight of a land-count lead: mana is what turns the hand into board.
const W_LANDS := 1.0


## Battlefield worth of one permanent (live characteristics).
static func permanent_value(inst: CardInstance) -> float:
	if inst.is_creature():
		var v := float(inst.cur_power + inst.cur_toughness)
		for k in inst.cur_keywords:
			v += KEYWORD_VALUE.get(k, 0.0)
		if inst.cur_protection != 0:
			v += 1.0
		if not inst.cur_landwalk.is_empty():
			v += 0.5
		v += inst.regeneration_shields * 0.5
		return maxf(v, 0.5)
	if inst.is_land():
		return 1.0
	# Artifacts/enchantments: rough worth by cost (they earned their slot).
	return maxf(inst.data.cost.mana_value() * 0.8, 1.0)


## Worth of a card as a thing to have/keep (hand, tutor, discard picks).
static func card_value(data: CardData) -> float:
	if data.is_land():
		return 1.5
	if data.is_creature():
		var v := float(data.power + data.toughness)
		for k in data.keywords:
			v += KEYWORD_VALUE.get(k, 0.0)
		return v
	# Spells: cost approximates power in this pool; free Power Nine
	# artifacts are worth plenty despite {0}.
	return maxf(data.cost.mana_value() + 1.0, 2.5)


## Overall position from [param pid]'s perspective; positive = ahead.
## The Adaptive posture (mage-go's idea) reads this: ahead → press the
## attack, behind → hold back and trade.
static func position_score(game: MtgGame, pid: int) -> float:
	var me := game.players[pid]
	var them := game.players[game.opponent_of(pid)]
	var score := (me.life - them.life) * W_LIFE
	var my_board := 0.0
	var their_board := 0.0
	for inst in me.battlefield:
		if not inst.is_land():
			my_board += permanent_value(inst)
	for inst in them.battlefield:
		if not inst.is_land():
			their_board += permanent_value(inst)
	score += (my_board - their_board) * W_BOARD
	score += (me.hand.size() - them.hand.size()) * W_HAND
	var my_lands := me.battlefield.filter(func(i: CardInstance) -> bool: return i.is_land()).size()
	var their_lands := them.battlefield.filter(func(i: CardInstance) -> bool: return i.is_land()).size()
	score += (my_lands - their_lands) * W_LANDS
	return score
