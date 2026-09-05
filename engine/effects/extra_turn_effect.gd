class_name ExtraTurnEffect
extends EffectBase
## "Take an extra turn after this one." — Time Walk.
##
## Queues the controller in MtgGame.extra_turns; _end_turn services the
## queue before passing the turn normally (CR 500.7). Multiple Time Walks
## queue multiple turns, resolving in cast order.


## Appends the controller to MtgGame.extra_turns. That queue is the only
## mutation — the turn machine drains it when the current turn ends, so a
## Time Walk cast on an opponent's turn still gives YOU the extra turn next.
func resolve(game: MtgGame, _source: CardInstance, controller: int, _target: TargetRef,
		_x_value: int = 0) -> void:
	game.extra_turns.append(controller)
	game.log_line("%s will take an extra turn" % game.players[controller].player_name)


## One-line log/UI text.
func describe() -> String:
	return "take an extra turn after this one"
