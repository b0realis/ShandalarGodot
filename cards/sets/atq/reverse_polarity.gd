extends CardScript
## Reverse Polarity — {W}{W} — Instant — (atq, common)
## Oracle: You gain X life, where X is twice the damage dealt to you so
##         far this turn by artifacts.
##
## Implementation: reads MtgPlayer.artifact_damage_this_turn — the
## per-turn counter MtgGame.deal_damage keeps whenever an ARTIFACT source
## damages a player — and doubles it. A dead card against anything but
## the artifact deck, which is exactly its job.


func build() -> CardData:
	return CardData.new("Reverse Polarity", "{W}{W}", Mtg.CardType.INSTANT) \
		.spell(PolarityEffect.new()) \
		.oracle("You gain X life, where X is twice the damage dealt to you so far "
			+ "this turn by artifacts.")


class PolarityEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var taken := game.players[controller].artifact_damage_this_turn
		if taken > 0:
			game.adjust_life(controller, taken * 2)

	func describe() -> String:
		return "gain twice the artifact damage you took this turn"
