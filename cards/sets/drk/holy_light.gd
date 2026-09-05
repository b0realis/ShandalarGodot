extends CardScript
## Holy Light — {2}{W} — Instant — (drk, common)
## Oracle: Nonwhite creatures get -1/-1 until end of turn.
##
## Implementation: a color-filtered mass shrink (marsh_gas.gd pattern) —
## every NONWHITE creature gets -1/-1; the toughness side means 1-toughness
## creatures die to the SBA.


func build() -> CardData:
	return CardData.new("Holy Light", "{2}{W}", Mtg.CardType.INSTANT) \
		.spell(HolyLightEffect.new()) \
		.oracle("Nonwhite creatures get -1/-1 until end of turn.")


class HolyLightEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		for inst in game.all_battlefield():
			if inst.is_creature() \
					and (inst.cur_colors & Mtg.ManaColor.W) == 0:
				game.continuous.add_until_eot_pump(inst.id, -1, -1, [])
		game.log_line("%s: nonwhite creatures get -1/-1" % source.data.card_name)
		game.recalculate()
		game.check_state_based_actions()

	func describe() -> String:
		return "nonwhite creatures get -1/-1 until end of turn"
