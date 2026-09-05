class_name DrawEffect
extends EffectBase
## "Draw N cards" — either for the effect's controller (untargeted, the
## default) or for a target player (Ancestral Recall style, via
## [method target_player]).

## How many cards to draw. Ignored when [member use_x] is set.
var count: int

## When true, draw X cards instead (Braingeyser).
var use_x: bool = false


func _init(p_count: int) -> void:
	count = p_count


## Fluent: make it "target player draws N cards".
func target_player() -> DrawEffect:
	target_spec = TargetSpec.player()
	return self


## Fluent: draw X cards instead of a fixed count.
func x_cards() -> DrawEffect:
	use_x = true
	return self


## Moves cards library → hand through MtgGame.draw_cards, which is also
## where drawing from an empty library arms the "you lose" check — so a
## Braingeyser aimed at the opponent is a kill spell, not just card draw.
func resolve(game: MtgGame, _source: CardInstance, controller: int, target: TargetRef,
		x_value: int = 0) -> void:
	var who := controller
	if target != null and target.is_player:
		who = target.player_id
	game.draw_cards(who, x_value if use_x else count)


## One-line log/UI text. Reports [member count] even for an X draw — the
## real number is not known until the spell is cast.
func describe() -> String:
	if target_spec != null:
		return "target player draws %d card(s)" % count
	return "draw %d card(s)" % count
