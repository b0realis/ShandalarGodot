extends CardScript
## Divine Intervention — {6}{W}{W} — Enchantment — (leg, rare)
## Oracle: This enchantment enters with two intervention counters on it.
##         At the beginning of your upkeep, remove an intervention counter
##         from this enchantment.
##         When you remove the last intervention counter from this
##         enchantment, the game is a draw.
##
## Implementation: the pool's only DRAW condition (CR 104.4). Two upkeeps
## after it lands, MtgGame.draw_game ends the game with no winner —
## game_over is true, winner stays -1 and is_draw records why.


func build() -> CardData:
	return CardData.new("Divine Intervention", "{6}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.with_enters_counters("intervention", 2) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _tick,
			"At the beginning of your upkeep, remove an intervention counter from this enchantment. When you remove the last one, the game is a draw.",
			_your_upkeep)) \
		.oracle("This enchantment enters with two intervention counters on it.\nAt the beginning of your upkeep, remove an intervention counter from this enchantment.\nWhen you remove the last intervention counter from this enchantment, the game is a draw.")


static func _your_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _tick(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var left: int = int(source.counters.get("intervention", 0)) - 1
	if left <= 0:
		source.counters.erase("intervention")
		game.draw_game("Divine Intervention ran out of counters")
		return
	source.counters["intervention"] = left
	game.log_line("Divine Intervention has %d intervention counter(s) left" % left)
