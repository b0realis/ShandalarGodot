extends CardScript
## Piety — {2}{W} — Instant — (4ed, common)
## Oracle: Blocking creatures get +0/+3 until end of turn.
##
## Implementation: card-local mass pump over the declared blockers —
## Morale's defensive twin (see morale.gd).


func build() -> CardData:
	return CardData.new("Piety", "{2}{W}", Mtg.CardType.INSTANT) \
		.spell(PietyEffect.new()) \
		.oracle("Blocking creatures get +0/+3 until end of turn.")


class PietyEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		for blocker_id in game.combat.blocks.keys():
			var inst := game.find_instance(blocker_id)
			if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD:
				game.continuous.add_until_eot_pump(inst.id, 0, 3, [])
		game.log_line("%s: blocking creatures get +0/+3" % source.data.card_name)
		game.recalculate()

	func describe() -> String:
		return "blocking creatures get +0/+3 until end of turn"
