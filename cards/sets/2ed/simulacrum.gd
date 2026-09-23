extends CardScript
## Simulacrum — {1}{B} — Instant — (2ed, uncommon)
## Oracle: You gain life equal to the damage dealt to you this turn.
##         Simulacrum deals damage to target creature you control equal to
##         the damage dealt to you this turn.
##
## Implementation: the engine now tracks how much damage each player has
## taken this turn (MtgPlayer.damage_taken_this_turn, cleared at cleanup),
## which is the number both halves of the card ask for. The life is gained
## first, so the creature's fate never changes the amount. The classic
## damage window also recovers its pending damage when it lands, before
## state-based deaths; modern play never covers future damage.


static func _yours(_game: MtgGame, source: CardInstance, inst: CardInstance) -> bool:
	return inst.controller_id == source.controller_id


func build() -> CardData:
	var spec := TargetSpec.creature("target creature you control")
	spec.with_source_filter(_yours)
	return CardData.new("Simulacrum", "{1}{B}", Mtg.CardType.INSTANT) \
		.spell(SimulacrumEffect.new(spec)) \
		.oracle("You gain life equal to the damage dealt to you this turn. Simulacrum deals damage to target creature you control equal to the damage dealt to you this turn.")


class SimulacrumEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		is_damage_prevention = true
		target_spec = spec

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		game.recover_damage_this_turn(controller, 1, false, source,
			game.find_instance(target.instance_id))

	func describe() -> String:
		return "you gain the damage you took this turn and pass it to your own creature"
