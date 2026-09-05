class_name AddManaEffect
extends EffectBase
## "Add [mana]" as a SPELL effect — Dark Ritual. (Lands and mana artifacts
## use ManaAbility instead; this class is for spells that resolve into
## mana.) The mana lands in the controller's pool and, per CR 500.4, empties
## at the end of the step — so ritual mana must be used in the same step,
## exactly like the real card.

## Array of [color: Mtg.ManaColor, amount: int] pairs.
var produces: Array = []


func _init(color: int, amount: int) -> void:
	produces = [[color, amount]]


## Fluent: produce additional mana of another type on the same resolution.
func and_also(color: int, amount: int = 1) -> AddManaEffect:
	produces.append([color, amount])
	return self


## Pours every [member produces] pair into the controller's ManaPool. The
## pool is the one piece of state that is NOT routed through an MtgGame
## mutation helper — it is spent inside cost payment, has no state-based
## actions and no triggers, and empties itself at end of step (CR 500.4).
func resolve(game: MtgGame, source: CardInstance, controller: int, _target: TargetRef,
		_x_value: int = 0) -> void:
	for pair in produces:
		game.players[controller].mana_pool.add(pair[0], pair[1])
	game.log_line("%s adds mana: %s" % [
		source.data.card_name, game.players[controller].mana_pool])


## One-line log/UI text.
func describe() -> String:
	return "adds mana"
