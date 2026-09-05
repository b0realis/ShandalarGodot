extends CardScript
## Floral Spuzzem — {3}{G} — Creature — Elemental — 2/2 — (leg, uncommon)
## Oracle: Whenever this creature attacks and isn't blocked, you may destroy
##         target artifact defending player controls. If you do, this
##         creature assigns no combat damage this turn.
##
## Implementation: a BLOCKERS_DECLARED trigger — the moment "attacks and
## isn't blocked" can first be answered — that offers the trade, and the
## trade is a real one: taking the artifact turns off the Spuzzem's combat
## damage for the turn (ContinuousEffects.add_until_eot_combat_prevention,
## the same shield Lady Evangela puts up).
##
## "Target artifact defending player controls" is a real TARGET of the
## trigger (TriggeredAbility.targeting): the Spuzzem's controller names it
## as the trigger goes on the stack (CR 603.3d) — a human seat is asked
## the moment a player would receive priority, with the original's
## generic prompt (`@ANIMATE_ARTIFACT`, `Program/prompts.txt`: "Select
## target artifact.") — an artifact with shroud is not on the list, with
## no artifact on the other side the trigger is removed instead (and the
## Spuzzem simply swings), and it fizzles if the artifact has left by
## resolution (CR 608.2b), in which case nothing was destroyed and the
## Spuzzem still deals its damage. The list is ranked by mana value, the
## dearest first, which is the heuristic seat's pick and the human seat's
## default highlight.
##
## The "you may" is decided as the trigger RESOLVES, with the target
## known (CR 603.5 — an optional trigger's controller chooses then),
## through the controller's DecisionAgent; declining leaves the Spuzzem
## swinging for 2. The heuristic takes the artifact when it is worth more
## than two points of damage, which is what a player does with a 2/2
## against a Nevinyrral's Disk.


func build() -> CardData:
	return CardData.new("Floral Spuzzem", "{3}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["elemental"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKERS_DECLARED, _smash,
			"Whenever this creature attacks and isn't blocked, you may destroy target artifact defending player controls. If you do, it assigns no combat damage this turn.",
			_unblocked) \
			.targeting(TargetSpec.new(TargetSpec.Kind.PERMANENT,
					"target artifact defending player controls", _is_artifact) \
				.with_source_filter(_defenders),
				_dearest_first, "Select target artifact.")) \
		.oracle("Whenever this creature attacks and isn't blocked, you may destroy "
			+ "target artifact defending player controls. If you do, this creature "
			+ "assigns no combat damage this turn.")


static func _unblocked(game: MtgGame, source: CardInstance,
		_event: GameEvent) -> bool:
	return source.zone == Mtg.Zone.BATTLEFIELD \
		and game.combat.attackers.has(source.id) \
		and not game.combat.was_blocked(game.combat.band_of(source.id))


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)


## "Defending player controls": the player the Spuzzem is attacking —
## with two seats, the one who does not control it.
static func _defenders(_game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	return source == null or inst.controller_id != source.controller_id


## The dearest artifact first.
static func _dearest_first(game: MtgGame, _source: CardInstance,
		a: TargetRef, b: TargetRef) -> bool:
	var ia := game.find_instance(a.instance_id)
	var ib := game.find_instance(b.instance_id)
	var va := ia.data.cost.mana_value()
	var vb := ib.data.cost.mana_value()
	if va != vb:
		return va > vb
	return ia.id < ib.id


static func _smash(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var refs: Array = game.current_targets()
	if refs.is_empty():
		return
	var pick := game.find_instance(refs[0].instance_id)
	if pick == null or pick.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	if not game.agents[pid].choose_yes_no(game, pid,
			"Destroy %s instead of dealing combat damage?"
				% pick.data.card_name, true):
		return
	game.destroy(pick)
	# "If you do, this creature assigns no combat damage this turn."
	game.continuous.add_until_eot_combat_prevention(source.id, true, false)
	game.recalculate()
