class_name ExileEffect
extends EffectBase
## "Exile target [creature/permanent]." — Ashes to Ashes, Swords to
## Plowshares' family.
##
## Exile is not destruction: no regeneration, no dies-trigger — the card
## simply ceases to exist for this game (MtgGame.exile_permanent). Attached
## auras are orphaned and swept by state-based actions.


func _init(spec: TargetSpec = null) -> void:
	target_spec = spec if spec != null else TargetSpec.creature()


## Moves the target battlefield → exile through MtgGame.exile_permanent.
## Deliberately NOT MtgGame.destroy: no DIES event fires, so Sengir Vampire
## grows no counter off a creature that Ashes to Ashes removed.
func resolve(game: MtgGame, _source: CardInstance, _controller: int, target: TargetRef,
		_x_value: int = 0) -> void:
	var inst := game.find_instance(target.instance_id)
	if inst != null:
		game.exile_permanent(inst)


## One-line log/UI text.
func describe() -> String:
	return "exiles %s" % target_spec.description
