extends CardScript
## Morale — {1}{W}{W} — Instant — (4ed, common)
## Oracle: Attacking creatures get +1/+1 until end of turn.
##
## Implementation: card-local mass pump over the declared attackers (ALL
## attacking creatures, either side of the table — in a two-player duel
## that's the active player's) — one floating +1/+1 per attacker.


func build() -> CardData:
	return CardData.new("Morale", "{1}{W}{W}", Mtg.CardType.INSTANT) \
		.spell(MoraleEffect.new()) \
		.oracle("Attacking creatures get +1/+1 until end of turn.")


class MoraleEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		for attacker_id in game.combat.attackers.keys():
			var inst := game.find_instance(attacker_id)
			if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD:
				game.continuous.add_until_eot_pump(inst.id, 1, 1, [])
		game.log_line("%s: attacking creatures get +1/+1" % source.data.card_name)
		game.recalculate()

	func describe() -> String:
		return "attacking creatures get +1/+1 until end of turn"
