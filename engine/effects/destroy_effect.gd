class_name DestroyEffect
extends EffectBase
## "Destroy target X." Optionally "It can't be regenerated." — Terror,
## Disenchant, Shatter, Stone Rain.
##
## Destruction is only a request: MtgGame.destroy consumes a regeneration
## shield instead of killing the permanent when one is up (CR 701.15), which
## is exactly what the "can't be regenerated" rider on Terror exists to beat.

## False for "it can't be regenerated" removal (Terror, Fissure) — every
## shield on the permanent is then ignored (CR 701.15d).
var can_regenerate: bool = true


func _init(spec: TargetSpec, p_can_regenerate: bool = true) -> void:
	target_spec = spec
	can_regenerate = p_can_regenerate


## Moves the target to its owner's graveyard through MtgGame.destroy (DIES
## event, regeneration check, aura sweep). A null instance means the target
## already left the game between casting and resolution; the standard fizzle
## check upstream normally catches that first.
func resolve(game: MtgGame, _source: CardInstance, _controller: int, target: TargetRef,
		_x_value: int = 0) -> void:
	var inst := game.find_instance(target.instance_id)
	if inst != null:
		game.destroy(inst, can_regenerate)


## One-line log/UI text.
func describe() -> String:
	var text := "destroys %s" % target_spec.description
	if not can_regenerate:
		text += " (no regeneration)"
	return text
