extends CardScript
## Army of Allah — {1}{W}{W} — Instant — (arn, common)
## Oracle: Attacking creatures get +2/+0 until end of turn.
##
## Implementation: Morale's power-heavy cousin (see morale.gd) — a mass
## +2/+0 over the declared attackers.


func build() -> CardData:
	return CardData.new("Army of Allah", "{1}{W}{W}", Mtg.CardType.INSTANT) \
		.spell(ArmyEffect.new()) \
		.oracle("Attacking creatures get +2/+0 until end of turn.")


class ArmyEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		for attacker_id in game.combat.attackers.keys():
			var inst := game.find_instance(attacker_id)
			if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD:
				game.continuous.add_until_eot_pump(inst.id, 2, 0, [])
		game.log_line("%s: attacking creatures get +2/+0" % source.data.card_name)
		game.recalculate()

	func describe() -> String:
		return "attacking creatures get +2/+0 until end of turn"
