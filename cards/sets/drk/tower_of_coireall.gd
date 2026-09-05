extends CardScript
## Tower of Coireall — {2} — Artifact — (drk, uncommon)
## Oracle: {T}: Target creature can't be blocked by Walls this turn.
##
## Implementation: a floating BLOCK RESTRICTION (new in this wave) —
## the same "can't be blocked except by …" list Invisibility and Elven
## Riders write into from statics, now available until end of turn.


func build() -> CardData:
	return CardData.new("Tower of Coireall", "{2}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("", true, [NoWallsEffect.new(_not_a_wall)],
			"{T}: Target creature can't be blocked by Walls this turn.")) \
		.oracle("{T}: Target creature can't be blocked by Walls this turn.")


## Walls need not apply.
static func _not_a_wall(blocker: CardInstance) -> bool:
	return not blocker.has_subtype("wall")


class NoWallsEffect extends EffectBase:
	var wall_filter: Callable

	func _init(filter: Callable = Callable()) -> void:
		target_spec = TargetSpec.creature()
		wall_filter = filter

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var runner := game.find_instance(target.instance_id)
		if runner == null or runner.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_block_restriction(
			runner.id, "creatures that aren't Walls", wall_filter)
		game.recalculate()

	func describe() -> String:
		return "target creature can't be blocked by Walls this turn"
