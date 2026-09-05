extends CardScript
## Festival — {W} — Instant — (drk, common)
## Oracle: Cast this spell only during an opponent's upkeep.
##         Creatures can't attack this turn.
##
## Implementation: a game-level ban for the turn (MtgGame.no_attacks_this_turn,
## cleared at cleanup) plus the printed timing rider — cast during their
## upkeep, before they ever reach declare-attackers.


static func _their_upkeep(game: MtgGame, pid: int) -> String:
	if game.active_player == pid:
		return "cast Festival only during an opponent's turn"
	if game.current_step() != Mtg.Step.UPKEEP:
		return "cast Festival only during an opponent's upkeep"
	return ""


func build() -> CardData:
	return CardData.new("Festival", "{W}", Mtg.CardType.INSTANT) \
		.castable_only_when(_their_upkeep) \
		.spell(FestivalEffect.new()) \
		.oracle("Cast this spell only during an opponent's upkeep.\nCreatures can't attack this turn.")


class FestivalEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.no_attacks_this_turn = true
		game.log_line("Creatures can't attack this turn")

	func describe() -> String:
		return "creatures can't attack this turn"
