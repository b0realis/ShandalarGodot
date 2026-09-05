class_name GainLifeEffect
extends EffectBase
## "[You / target player] gain(s) N (or X) life." Negative amounts model
## plain life LOSS (not damage — no prevention applies, per CR 119.6/7).

## Life gained; NEGATIVE means life loss (Dark Heart of the Wood pays,
## Grave Robbers gains). Ignored when [member use_x] is set.
var amount: int

## When true the amount is the spell's X (Stream of Life, Alabaster Potion).
var use_x: bool = false


func _init(p_amount: int) -> void:
	amount = p_amount


## Fluent: "target player gains ..." (Stream of Life).
func target_player() -> GainLifeEffect:
	target_spec = TargetSpec.player()
	return self


## Fluent: the amount is X.
func x_amount() -> GainLifeEffect:
	use_x = true
	return self


## Changes MtgPlayer.life through MtgGame.adjust_life — the helper that
## applies Lich's replacement ("if you would gain life, draw that many cards
## instead") and rechecks the life ≤ 0 state-based action, which is how a
## negative amount can end the game on the spot.
func resolve(game: MtgGame, _source: CardInstance, controller: int, target: TargetRef,
		x_value: int = 0) -> void:
	var who := controller
	if target != null and target.is_player:
		who = target.player_id
	game.adjust_life(who, x_value if use_x else amount)


## One-line log/UI text.
func describe() -> String:
	var n := "X" if use_x else str(absi(amount))
	var verb := "gains" if (use_x or amount >= 0) else "loses"
	var who := "target player" if target_spec != null else "you"
	return "%s %s %s life" % [who, verb, n]
