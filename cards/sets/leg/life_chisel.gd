extends CardScript
## Life Chisel — {4} — Artifact — (leg, uncommon)
## Oracle: Sacrifice a creature: You gain life equal to the sacrificed
##         creature's toughness. Activate only during your upkeep.
##
## Implementation: Diamond Valley's payload on an artifact, with no tap
## in the cost but restricted to its controller's upkeep — so the whole
## board can be cashed in, but only once a turn cycle and only before you
## would have attacked with it.


func build() -> CardData:
	return CardData.new("Life Chisel", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"", false, [ChiselEffect.new()],
			"Sacrifice a creature: You gain life equal to the sacrificed creature's "
			+ "toughness. Activate only during your upkeep.") \
			.with_sacrifice_of("creature", _is_creature) \
			.during_step(Mtg.Step.UPKEEP).your_turn_only()) \
		.oracle("Sacrifice a creature: You gain life equal to the sacrificed "
			+ "creature's toughness. Activate only during your upkeep.")


static func _is_creature(inst: CardInstance) -> bool:
	return inst.is_creature()


class ChiselEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		# Diamond Valley's payload: the engine snapshots the sacrificed
		# body's LIVE toughness onto THIS ACTIVATION's stack item as the
		# cost is paid (CR 608.2h), which also covers tokens. The Chisel
		# costs no mana, so two of them on the stack is a normal line and
		# a record on the permanent would have them read each other's.
		var toughness := int(game.cost_paid("_sacrificed_toughness", -1))
		if toughness >= 0:
			game.adjust_life(controller, toughness)

	func describe() -> String:
		return "gain life equal to the sacrificed creature's toughness"
