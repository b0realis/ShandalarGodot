extends CardScript
## Erhnam Djinn — {3}{G} — Creature — Djinn — 4/5 — (arn, rare)
## Oracle: At the beginning of your upkeep, target non-Wall creature an
##         opponent controls gains forestwalk until your next upkeep. (It
##         can't be blocked as long as defending player controls a Forest.)
##
## Implementation: the best green body of its era, rented against one of
## the opponent's creatures walking past your Forests. The gift is a
## FLOATING landwalk grant with the printed duration —
## ContinuousEffects.Duration.UNTIL_UPKEEP_OF the Djinn's controller
## (CR 611.2b) — not a static of the Djinn's, so killing the Djinn in
## response to the trigger, or at any point in the turn that follows, does
## not take the forestwalk back. MtgGame ends the grant as that upkeep
## begins, which is BEFORE this trigger fires again, so each turn's gift
## replaces the last one exactly as printed.
##
## "Target non-Wall creature an opponent controls" is a real TARGET of
## the upkeep trigger (TriggeredAbility.targeting): the Djinn's controller
## names it as the trigger goes on the stack (CR 603.3d) — a human seat
## is asked the moment a player would receive priority, with the
## original's own prompt (`@ERHNAM_DJINN`, `Program/promptsX1.txt:170`:
## "Select opponent non-wall creature.") — a Wall or a creature with
## shroud is not on the list, with no such creature the trigger is
## removed instead, and it fizzles if the creature has left by resolution
## (CR 608.2b): no forestwalk that turn. The candidates are ranked WORST
## body first: the Djinn's controller would never hand forestwalk to the
## biggest threat, so that is the heuristic seat's answer and the human
## seat's default highlight.


func build() -> CardData:
	return CardData.new("Erhnam Djinn", "{3}{G}", Mtg.CardType.CREATURE) \
		.pt(4, 5) \
		.with_subtypes(["djinn"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _bestow,
			"At the beginning of your upkeep, target non-Wall creature an opponent controls gains forestwalk until your next upkeep.",
			_own_upkeep) \
			.targeting(TargetSpec.creature(
					"target non-Wall creature an opponent controls", _non_wall) \
				.with_source_filter(_an_opponents),
				_weakest_first, "Select opponent non-wall creature.")) \
		.oracle("At the beginning of your upkeep, target non-Wall creature an opponent "
			+ "controls gains forestwalk until your next upkeep. (It can't be blocked as "
			+ "long as defending player controls a Forest.)")


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _non_wall(inst: CardInstance) -> bool:
	return not inst.has_subtype("wall")


static func _an_opponents(_game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	return source == null or inst.controller_id != source.controller_id


## The weakest body first.
static func _weakest_first(game: MtgGame, _source: CardInstance,
		a: TargetRef, b: TargetRef) -> bool:
	var ia := game.find_instance(a.instance_id)
	var ib := game.find_instance(b.instance_id)
	var va := ia.cur_power + ia.cur_toughness
	var vb := ib.cur_power + ib.cur_toughness
	if va != vb:
		return va < vb
	return ia.id < ib.id


static func _bestow(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	# CR 603.6: the trigger resolves even if the Djinn has already died.
	var pid := int(event.data["player"])
	var refs: Array = game.current_targets()
	if refs.is_empty():
		return
	var pick := game.find_instance(refs[0].instance_id)
	if pick == null or pick.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.continuous.add_until_eot_landwalk(pick.id, ["forest"], false,
		ContinuousEffects.Duration.UNTIL_UPKEEP_OF, pid)
	game.recalculate()
