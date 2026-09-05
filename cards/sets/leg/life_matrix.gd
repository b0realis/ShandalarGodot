extends CardScript
## Life Matrix — {4} — Artifact — (leg, rare)
## Oracle: {4}, {T}: Put a matrix counter on target creature and that
##         creature gains "Remove a matrix counter from this creature:
##         Regenerate this creature." Activate only during your upkeep.
##
## Implementation: the counter is real and so is the grant. The ability is
## registered on the CREATURE through
## ContinuousEffects.add_granted_activated_ability, which defaults to the
## INDEFINITE duration a grant with no stated duration has (CR 611.2b) —
## so destroying the Matrix leaves every creature it ever shielded holding
## the ability, exactly as printed. `with_counter_cost` is the engine's
## "remove N counters as a COST", so the shield really costs the counter
## and a creature with two matrix counters can regenerate twice.
##
## The grant is durationless but not eternal: it is keyed to the INSTANCE,
## so a creature that leaves the battlefield and comes back is a new object
## and arrives with neither counter nor ability (CR 400.7).
##
## The timing rider is two engine flags: your turn only, upkeep step only.


func build() -> CardData:
	return CardData.new("Life Matrix", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{4}", true, [MatrixEffect.new()],
			"{4}, {T}: Put a matrix counter on target creature and that creature gains \"Remove a matrix counter from this creature: Regenerate this creature.\"") \
			.your_turn_only() \
			.during_step(Mtg.Step.UPKEEP)) \
		.oracle("{4}, {T}: Put a matrix counter on target creature and that creature gains "
			+ "\"Remove a matrix counter from this creature: Regenerate this creature.\" "
			+ "Activate only during your upkeep.")


class MatrixEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	## The granted ability, built fresh per grant so nothing is shared
	## between creatures.
	static func _shield() -> ActivatedAbility:
		return ActivatedAbility.new("", false, [RegenerateEffect.new()],
			"Remove a matrix counter from this creature: Regenerate this creature.") \
			.with_counter_cost("matrix", 1)

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.add_counters(inst, "matrix", 1)
		game.continuous.add_granted_activated_ability(inst.id, _shield())
		game.recalculate()

	func describe() -> String:
		return "puts a matrix counter on target creature"
