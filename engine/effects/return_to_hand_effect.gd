class_name ReturnToHandEffect
extends EffectBase
## "Return target [permanent] to its owner's hand." — Unsummon.
##
## Bouncing is not destruction: no regeneration, no dies-trigger. Attached
## auras are orphaned and swept to the graveyard by state-based actions
## (CR 704.5m) — MtgGame.return_to_hand handles the move itself.


func _init(spec: TargetSpec = null) -> void:
	target_spec = spec if spec != null else TargetSpec.creature()


## Moves the target battlefield → its OWNER's hand through
## MtgGame.return_to_hand (owner, not controller — CR 400.3, which is how
## Unsummon undoes a Control Magic steal permanently).
func resolve(game: MtgGame, _source: CardInstance, _controller: int, target: TargetRef,
		_x_value: int = 0) -> void:
	var inst := game.find_instance(target.instance_id)
	if inst != null:
		game.return_to_hand(inst)


## One-line log/UI text.
func describe() -> String:
	return "returns %s to its owner's hand" % target_spec.description
