class_name MillEffect
extends EffectBase
## "Target player mills N cards" (puts them from the top of their library
## into their graveyard) — Millstone's payload. Milling out is not a loss;
## only drawing from an empty library is (CR 120.3).

## How many cards to move off the top of the library.
var count: int


func _init(p_count: int) -> void:
	count = p_count
	target_spec = TargetSpec.player()


## Moves cards library → graveyard through MtgGame.mill, which stops early on
## an empty library rather than arming the draw-out loss — milling the last
## card is survivable, drawing after it is not.
func resolve(game: MtgGame, _source: CardInstance, controller: int, target: TargetRef,
		_x_value: int = 0) -> void:
	var who := controller
	if target != null and target.is_player:
		who = target.player_id
	game.mill(who, count)


## One-line log/UI text.
func describe() -> String:
	return "target player mills %d card(s)" % count
