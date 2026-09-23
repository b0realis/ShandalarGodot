extends CardScript
## Reverse Polarity — {W}{W} — Instant — (atq, common)
## Oracle: You gain X life, where X is twice the damage dealt to you so
##         far this turn by artifacts.
##
## Implementation: reads MtgPlayer.artifact_damage_this_turn — the
## per-turn counter MtgGame.deal_damage keeps whenever an ARTIFACT source
## damages a player — and doubles it. In the classic prevention window,
## also recovers that window's damage when it actually lands; prevention
## and redirection cannot manufacture extra life. Modern play still only
## counts damage already dealt when the spell resolves.


func build() -> CardData:
	return CardData.new("Reverse Polarity", "{W}{W}", Mtg.CardType.INSTANT) \
		.spell(PolarityEffect.new()) \
		.oracle("You gain X life, where X is twice the damage dealt to you so far "
			+ "this turn by artifacts.")


class PolarityEffect extends EffectBase:
	func _init() -> void:
		is_damage_prevention = true

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.recover_damage_this_turn(controller, 2, true)

	func describe() -> String:
		return "gain twice the artifact damage you took this turn"
