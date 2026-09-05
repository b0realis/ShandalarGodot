extends CardScript
## Halfdane — {1}{W}{U}{B} — Legendary Creature — Shapeshifter — 3/3 — (leg, rare)
## Oracle: At the beginning of your upkeep, change Halfdane's base power and
##         toughness to the power and toughness of target creature other
##         than Halfdane until the end of your next upkeep.
##
## Implementation: "target creature other than Halfdane" is a real TARGET
## of the upkeep trigger (TriggeredAbility.targeting): Halfdane's
## controller names it as the trigger goes on the stack (CR 603.3d) — a
## human seat is asked the moment a player would receive priority, with
## the original's generic prompt (`@TARGET_CREATURE`, `Program/prompts.txt`:
## "Select target creature.") — a creature with shroud is not on the
## list, with no other creature at all the trigger is removed instead,
## and it fizzles if the creature has left by resolution (CR 608.2b).
## Either side's creatures are legal; the list is ranked biggest first,
## which is the heuristic seat's pick and the human seat's default
## highlight.
##
## The borrowed body is a FLOATING base-P/T set (CR 613 layer 7b, so
## pumps and counters still stack on top) with the printed duration —
## ContinuousEffects.Duration.UNTIL_END_OF_UPKEEP_OF Halfdane's controller
## (CR 611.2b): it lasts through the next upkeep and ends as that step
## ends, so a shape Halfdane cannot renew (no legal target, or a trigger
## that fizzled) runs out then and it is a 3/3 again. A renewed shape is
## a later timestamp and simply wins while both are in force. The power
## and toughness copied are the target's CURRENT ones as the trigger
## resolves (a pumped target lends its pumped body), which is what the
## printed text says.


func build() -> CardData:
	return CardData.new("Halfdane", "{1}{W}{U}{B}", Mtg.CardType.CREATURE) \
		.pt(3, 3) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["shapeshifter"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _take_a_shape,
			"At the beginning of your upkeep, change Halfdane's base power and toughness to those of target creature other than Halfdane until the end of your next upkeep.",
			_your_upkeep) \
			.targeting(TargetSpec.creature("target creature other than Halfdane") \
				.with_source_filter(_other_than_self),
				_biggest_first, "Select target creature.")) \
		.oracle("At the beginning of your upkeep, change Halfdane's base power and toughness to the power and toughness of target creature other than Halfdane until the end of your next upkeep.")


static func _your_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _other_than_self(_game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	return inst != source


## The biggest body first, whoever controls it.
static func _biggest_first(game: MtgGame, _source: CardInstance,
		a: TargetRef, b: TargetRef) -> bool:
	var ia := game.find_instance(a.instance_id)
	var ib := game.find_instance(b.instance_id)
	var va := ia.cur_power + ia.cur_toughness
	var vb := ib.cur_power + ib.cur_toughness
	if va != vb:
		return va > vb
	return ia.id < ib.id


static func _take_a_shape(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var refs: Array = game.current_targets()
	if refs.is_empty():
		return
	var model := game.find_instance(refs[0].instance_id)
	if model == null or model.zone != Mtg.Zone.BATTLEFIELD:
		return
	# `exact`: a model shrunk below 0 power (a Weakness on a Wall of Wood)
	# is copied as it is — -1 is a value here, not the "leave that half
	# alone" sentinel the helper reads otherwise.
	game.continuous.add_until_eot_base_pt(source.id, model.cur_power,
		model.cur_toughness, false,
		ContinuousEffects.Duration.UNTIL_END_OF_UPKEEP_OF,
		source.controller_id, game.turn_number, true)
	game.log_line("Halfdane takes the shape of %s (%d/%d)" % [
		model.data.card_name, model.cur_power, model.cur_toughness])
	game.recalculate()
	game.check_state_based_actions()
