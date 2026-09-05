class_name DestroyAllEffect
extends EffectBase
## Mass removal: "Destroy all [filter]." — Wrath of God's effect.
##
## Untargeted (no target_spec): mass effects don't target, which is exactly
## why Wrath kills protection-from-white creatures — protection's DEBT
## bundle never comes into play. The filter Callable
## [code]func(inst: CardInstance) -> bool[/code] selects victims;
## [member description] states the scope in card English.

## Selects which battlefield permanents die. Unset = all creatures.
var filter: Callable = Callable()

## Card-English scope ("all creatures"), for logs.
var description: String = "all creatures"

## False for "they can't be regenerated" sweepers (Wrath of God, Shatterstorm)
## — MtgGame.destroy then ignores every regeneration shield (CR 701.15d).
var can_regenerate: bool = true


func _init(p_description: String = "all creatures",
		p_filter: Callable = Callable(), p_can_regenerate := true) -> void:
	description = p_description
	filter = p_filter
	can_regenerate = p_can_regenerate


## Moves every matching permanent to its owner's graveyard through
## MtgGame.destroy, which fires the DIES event, honours regeneration shields
## unless [member can_regenerate] is false, and sweeps orphaned auras.
func resolve(game: MtgGame, _source: CardInstance, _controller: int, _target: TargetRef,
		_x_value: int = 0) -> void:
	# Snapshot first: destroying mutates the battlefield lists.
	var victims: Array[CardInstance] = []
	for inst in game.all_battlefield():
		if filter.is_valid():
			if filter.call(inst):
				victims.append(inst)
		elif inst.is_creature():
			victims.append(inst)
	for inst in victims:
		game.destroy(inst, can_regenerate)


## One-line log/UI text.
func describe() -> String:
	var text := "destroys " + description
	if not can_regenerate:
		text += " (no regeneration)"
	return text
