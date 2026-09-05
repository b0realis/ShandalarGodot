extends CardScript
## Blazing Effigy — {1}{R} — Creature — Elemental — 0/3 — (leg, common)
## Oracle: When this creature dies, it deals X damage to target creature,
##         where X is 3 plus the amount of damage dealt to this creature
##         this turn by other sources named Blazing Effigy.
##
## Implementation: the chain, with a real AMOUNT, read out of the engine's
## own per-source ledger — CardInstance.damage_from_this_turn, source id ->
## how much that source dealt to this creature this turn, snapshotted into
## the DIES event as `damaged_by_amounts` before the battlefield state is
## wiped (CR 608.2h). So EVERY point an Effigy dealt counts, however it was
## dealt: a chain of dies-triggers escalates 3, 6, 9, and a Giant Growth'd
## Effigy that bit in combat adds its bite too.
##
## "Other sources NAMED Blazing Effigy" is a name check on each id in that
## ledger, so a Clone of one counts and the creature's own damage does not.
##
## "Target creature" is a real TARGET of the dies trigger
## (TriggeredAbility.targeting): the Effigy's controller names it as the
## trigger goes on the stack (CR 603.3d) — a human seat is asked the
## moment a player would receive priority, with the original's generic
## prompt (`@TARGET_CREATURE`, `Program/prompts.txt`: "Select target
## creature.") — a creature with shroud or protection from red is not on
## the list, with no creature at all the trigger is removed instead, and
## it fizzles if the creature has left by resolution (CR 608.2b). Either
## side's creatures are legal (the chain of Effigies is the point of the
## card); the list is ranked the opponent's first, biggest first, which
## is the heuristic seat's pick and the human seat's default highlight.


func build() -> CardData:
	return CardData.new("Blazing Effigy", "{1}{R}", Mtg.CardType.CREATURE) \
		.pt(0, 3) \
		.with_subtypes(["elemental"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DIES, _blaze,
			"When this creature dies, it deals X damage to target creature, where X is 3 plus the damage dealt to it this turn by other Blazing Effigies.",
			_is_self) \
			.targeting(TargetSpec.creature(), _enemy_biggest_first,
				"Select target creature.")) \
		.oracle("When this creature dies, it deals X damage to target creature, where X is 3 plus the amount of damage dealt to this creature this turn by other sources named Blazing Effigy.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


## "The amount of damage dealt to this creature this turn by OTHER sources
## named Blazing Effigy", out of a per-source ledger (live or snapshotted).
## [param exclude] is the dying Effigy itself — "other sources".
static func _effigy_damage(game: MtgGame, amounts: Dictionary,
		exclude: int) -> int:
	var total := 0
	for id in amounts:
		if int(id) == exclude:
			continue
		var biter := game.find_instance(int(id))
		if biter != null and biter.data.card_name == "Blazing Effigy":
			total += int(amounts[id])
	return total


## The opponent's creatures before your own, the biggest first. (The
## Effigy is in the graveyard by now; its controller_id has been reset to
## its owner, which is who is choosing.)
static func _enemy_biggest_first(game: MtgGame, source: CardInstance,
		a: TargetRef, b: TargetRef) -> bool:
	var ia := game.find_instance(a.instance_id)
	var ib := game.find_instance(b.instance_id)
	var a_enemy := ia.controller_id != source.controller_id
	var b_enemy := ib.controller_id != source.controller_id
	if a_enemy != b_enemy:
		return a_enemy
	var va := ia.cur_power + ia.cur_toughness
	var vb := ib.cur_power + ib.cur_toughness
	if va != vb:
		return va > vb
	return ia.id < ib.id


static func _blaze(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var bonus := _effigy_damage(game,
		event.data.get("damaged_by_amounts", {}), source.id)
	var refs: Array = game.current_targets()
	if refs.is_empty():
		return
	# deal_damage keeps the ledger itself, and keeps it HONESTLY — what
	# lands after prevention shields and redirections is what is recorded,
	# and it is recorded before the state-based actions kill the victim, so
	# the next Effigy in the chain reads the right number.
	game.deal_damage(source, refs[0], 3 + bonus)
