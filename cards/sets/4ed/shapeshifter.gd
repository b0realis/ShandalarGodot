extends CardScript
## Shapeshifter — {6} — Artifact Creature — Shapeshifter — */7-* — (4ed, uncommon)
## Oracle: As this creature enters, choose a number between 0 and 7.
##         At the beginning of your upkeep, you may choose a number between
##         0 and 7.
##         Shapeshifter's power is equal to the last chosen number and its
##         toughness is equal to 7 minus that number.
##
## Implementation: seven points of stats, split by its controller and
## re-split once a turn. The number lives in CardInstance.memory (cleared
## when it leaves the battlefield, CR 400.7) and is published by a
## characteristic-defining static (CR 613 layer 7b, `setting_base_pt`), so
## counters and anthems still stack on top of whatever was chosen — the
## original's own ruling: *"It only changes its base power and toughness;
## any modifiers to these stats (such as counters) are applied normally to
## the numbers you choose"* (Duel.hlp, Shapeshifter).
##
## The first split is an "as it enters" REPLACEMENT (CR 614.1c,
## CardData.as_it_enters), not a trigger: nothing ever sees an unshaped
## body. The re-split is an upkeep trigger, and once a turn is all the
## original allowed too — *"It can only change its power and toughness once
## each turn"*.
##
## The number is a real question (DecisionAgent.choose_number). The
## heuristic answer keeps it alive: enough toughness to outlast the biggest
## power an opponent has on the board, everything else in power — and never
## 7, which would be a 7/0 that dies to the state-based actions on the
## spot.
##
## Duel.hlp's own card text makes the upkeep re-split MANDATORY ("During
## your upkeep, choose Shapeshifter's power and toughness"); the oracle
## makes it optional and we follow the oracle, so the trigger asks first.


const TOTAL := 7


func build() -> CardData:
	return CardData.new("Shapeshifter", "{6}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(0, 0) \
		.with_subtypes(["shapeshifter"]) \
		.as_it_enters(_choose_on_arrival) \
		.static_ability(StaticAbility.new(
			_apply,
			"Shapeshifter's power is equal to the last chosen number and its "
			+ "toughness is equal to 7 minus that number.").setting_base_pt()) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _reshape,
			"At the beginning of your upkeep, you may choose a number between 0 and 7.",
			_own_upkeep)) \
		.oracle("As this creature enters, choose a number between 0 and 7.\n"
			+ "At the beginning of your upkeep, you may choose a number between 0 and 7.\n"
			+ "Shapeshifter's power is equal to the last chosen number and its "
			+ "toughness is equal to 7 minus that number.")


## The split a player would take: survive the board, then hit as hard as
## what is left allows. Never 7 — that is a 7/0 (CR 704.5f).
static func best_number(game: MtgGame, source: CardInstance) -> int:
	var biggest := 0
	for inst in game.players[game.opponent_of(source.controller_id)].battlefield:
		if inst.is_creature():
			biggest = maxi(biggest, inst.cur_power)
	return clampi(TOTAL - 1 - biggest, 0, TOTAL - 1)


static func _ask(game: MtgGame, source: CardInstance) -> void:
	var pid := source.controller_id
	source.memory["shape"] = game.agents[pid].choose_number(game, pid,
		0, TOTAL, "Choose Shapeshifter's power (its toughness is 7 minus it)",
		best_number(game, source))


static func _choose_on_arrival(game: MtgGame, inst: CardInstance,
		_controller: int) -> void:
	_ask(game, inst)


static func _own_upkeep(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return event.data["player"] == source.controller_id


static func _reshape(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	var wanted := best_number(game, source)
	if not game.agents[pid].choose_yes_no(game, pid,
			"Re-split Shapeshifter's power and toughness?",
			wanted != int(source.memory.get("shape", 0))):
		return
	_ask(game, source)
	game.recalculate()


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	var n: int = clampi(int(source.memory.get("shape", 0)), 0, TOTAL)
	source.cur_power = n
	source.cur_toughness = TOTAL - n
