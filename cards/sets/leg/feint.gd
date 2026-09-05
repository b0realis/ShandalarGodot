extends CardScript
## Feint — {R} — Instant — (leg, common)
## Oracle: Tap all creatures blocking target attacking creature. Prevent
##         all combat damage that would be dealt this turn by that creature
##         and each creature blocking it.
##
## Implementation: the whole fight is called off. Tapping the blockers is
## cosmetic in this combat (they stay blocking) but real for the rest of
## the turn; the prevention is the floating combat-damage shield the engine
## already uses for Lady Evangela, applied to both sides of the block.


static func _is_attacking(game: MtgGame, inst: CardInstance) -> bool:
	return game.combat.attackers.has(inst.id)


func build() -> CardData:
	var spec := TargetSpec.creature("target attacking creature")
	spec.with_game_filter(_is_attacking)
	return CardData.new("Feint", "{R}", Mtg.CardType.INSTANT) \
		.spell(FeintEffect.new(spec)) \
		.oracle("Tap all creatures blocking target attacking creature. Prevent all combat damage that would be dealt this turn by that creature and each creature blocking it.")


class FeintEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var attacker := game.find_instance(target.instance_id)
		if attacker == null or attacker.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_combat_prevention(attacker.id, true, false)
		for blocker_id in game.combat.blockers_of(attacker.id):
			var blocker := game.find_instance(blocker_id)
			if blocker == null or blocker.zone != Mtg.Zone.BATTLEFIELD:
				continue
			game.tap_permanent(blocker)
			game.continuous.add_until_eot_combat_prevention(blocker.id, true, false)
		game.recalculate()

	func describe() -> String:
		return "taps the blockers and calls off the fight"
