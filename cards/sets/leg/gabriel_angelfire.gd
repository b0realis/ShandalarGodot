extends CardScript
## Gabriel Angelfire — {3}{G}{G}{W}{W} — Legendary Creature — Angel — 4/4 — (leg, rare)
## Oracle: At the beginning of your upkeep, choose flying, first strike,
##         trample, or rampage 3. Gabriel Angelfire gains that ability
##         until your next upkeep. (Whenever a creature with rampage 3
##         becomes blocked, it gets +3/+3 until end of turn for each
##         creature blocking it beyond the first.)
##
## Implementation: the choice is a real question over four labelled options
## (DecisionAgent.choose_option) and lands in CardInstance.memory; a STATIC
## ability reads it and grants the ability every recalculation. "Until your
## next upkeep" therefore needs no duration machinery at all — the next
## upkeep's trigger overwrites the memory, and CR 400.7 clears it if
## Gabriel leaves. Rampage rides on CardInstance.cur_rampage, the live
## value combat reads.
##
## Nothing is granted before his FIRST upkeep: as printed, an Angel that
## just landed is a plain 4/4 until the turn comes round.
##
## THE HEURISTIC, in the order a player would think:
##  1. FLYING while nothing across the table can block a flier — a 4/4 in
##     the air is simply unanswerable.
##  2. RAMPAGE 3 against a board of three or more, where a gang block is
##     the plan and rampage punishes it hardest.
##  3. FIRST STRIKE against anything with power 4 or more, the only
##     creatures that trade with him.
##  4. TRAMPLE otherwise, to push damage past the chump blocker.
##
## Duel.hlp does not cover him — the shipped help file is the base game's
## pool, and Legends arrived with the expansion. mage-go implements the
## same four modes through its own mode chooser.


const CHOICES: Array[String] = ["Flying", "First strike", "Trample", "Rampage 3"]
const FLYING := 0
const FIRST_STRIKE := 1
const TRAMPLE := 2
const RAMPAGE := 3


func build() -> CardData:
	return CardData.new("Gabriel Angelfire", "{3}{G}{G}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(4, 4) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["angel"]) \
		.static_ability(StaticAbility.new(
			_apply, "Gabriel Angelfire has the ability chosen at your last upkeep.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _choose,
			"At the beginning of your upkeep, choose flying, first strike, "
			+ "trample, or rampage 3. Gabriel Angelfire gains that ability until "
			+ "your next upkeep.",
			_own_upkeep)) \
		.oracle("At the beginning of your upkeep, choose flying, first strike, "
			+ "trample, or rampage 3. Gabriel Angelfire gains that ability until "
			+ "your next upkeep. (Whenever a creature with rampage 3 becomes "
			+ "blocked, it gets +3/+3 until end of turn for each creature blocking "
			+ "it beyond the first.)")


static func _own_upkeep(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return source.zone == Mtg.Zone.BATTLEFIELD \
		and event.data["player"] == source.controller_id


## What a player would pick against the board in front of them.
static func best_choice(game: MtgGame, source: CardInstance) -> int:
	var them := game.opponent_of(source.controller_id)
	var creatures := 0
	var can_catch_a_flier := false
	var heavy := false
	for inst in game.players[them].battlefield:
		if not inst.is_creature():
			continue
		creatures += 1
		if inst.has_keyword(Mtg.Keyword.FLYING) or inst.has_keyword(Mtg.Keyword.REACH):
			can_catch_a_flier = true
		if inst.cur_power >= 4:
			heavy = true
	if not can_catch_a_flier:
		return FLYING
	if creatures >= 3:
		return RAMPAGE
	if heavy:
		return FIRST_STRIKE
	return TRAMPLE


static func _choose(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	source.memory["gift"] = game.agents[pid].choose_option(game, pid, CHOICES,
		"Choose an ability for Gabriel Angelfire", best_choice(game, source))
	game.recalculate()


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	if not source.memory.has("gift"):
		return   # not yet through an upkeep — a plain 4/4
	match int(source.memory["gift"]):
		FLYING:
			if not source.cur_keywords.has(Mtg.Keyword.FLYING):
				source.cur_keywords.append(Mtg.Keyword.FLYING)
		FIRST_STRIKE:
			if not source.cur_keywords.has(Mtg.Keyword.FIRST_STRIKE):
				source.cur_keywords.append(Mtg.Keyword.FIRST_STRIKE)
		TRAMPLE:
			if not source.cur_keywords.has(Mtg.Keyword.TRAMPLE):
				source.cur_keywords.append(Mtg.Keyword.TRAMPLE)
		RAMPAGE:
			source.cur_rampage = maxi(source.cur_rampage, 3)
