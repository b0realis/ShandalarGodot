extends CardScript
## Dwarven Weaponsmith — {1}{R} — Creature — Dwarf Artificer — 1/1 — (atq, uncommon)
## Oracle: {T}, Sacrifice an artifact: Put a +1/+1 counter on target
##         creature. Activate only during your upkeep.
##
## Implementation: a tap-and-sacrifice ability restricted to the UPKEEP
## step of its controller's turn (during_step + your_turn_only). One
## artifact a turn becomes a permanent +1/+1 — slow, but counters survive
## everything a pump spell doesn't.


func build() -> CardData:
	return CardData.new("Dwarven Weaponsmith", "{1}{R}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["dwarf", "artificer"]) \
		.activated(ActivatedAbility.new(
			"", true, [AddCounterEffect.new()],
			"{T}, Sacrifice an artifact: Put a +1/+1 counter on target creature. "
			+ "Activate only during your upkeep.") \
			.with_sacrifice_of("artifact", _is_artifact) \
			.during_step(Mtg.Step.UPKEEP).your_turn_only()) \
		.oracle("{T}, Sacrifice an artifact: Put a +1/+1 counter on target creature. "
			+ "Activate only during your upkeep.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)


class AddCounterEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD:
			game.add_counters(inst, "+1/+1", 1)

	func describe() -> String:
		return "puts a +1/+1 counter on target creature"
