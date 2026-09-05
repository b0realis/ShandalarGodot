class_name ReturnFromGraveyardEffect
extends EffectBase
## "Return target [creature] card from your graveyard to your hand." —
## Raise Dead (creatures only, the default) and Regrowth (any card, via
## [method any_card]). Legality is re-checked at resolution: if the card
## left the graveyard in response — e.g. a second Raise Dead got it first —
## this fizzles normally.


func _init() -> void:
	target_spec = TargetSpec.new(TargetSpec.Kind.CREATURE_IN_YOUR_GRAVEYARD)


## Fluent: accept ANY card type in the graveyard (Regrowth).
func any_card() -> ReturnFromGraveyardEffect:
	target_spec = TargetSpec.new(TargetSpec.Kind.CARD_IN_YOUR_GRAVEYARD)
	return self


## When true the card returns to the BATTLEFIELD instead of the hand
## (Resurrection) — via MtgGame.reanimate, so it enters under the effect
## controller's control with all normal entering rules (sickness, ETB
## triggers). Set with [method to_battlefield].
var to_battlefield_mode: bool = false


## Fluent: return to the battlefield instead of the hand (Resurrection).
func to_battlefield() -> ReturnFromGraveyardEffect:
	to_battlefield_mode = true
	return self


## Moves the card graveyard → hand (MtgGame.return_from_graveyard_to_hand)
## or graveyard → battlefield (MtgGame.reanimate). The battlefield route goes
## through reanimate rather than a raw zone move so the creature enters
## under the EFFECT's controller and takes the normal entering path — ETB
## triggers and summoning sickness included (Resurrection, Hell's Caretaker).
func resolve(game: MtgGame, _source: CardInstance, controller: int, target: TargetRef,
		_x_value: int = 0) -> void:
	var inst := game.find_instance(target.instance_id)
	if inst == null:
		return
	if to_battlefield_mode:
		game.reanimate(inst, controller)
	else:
		game.return_from_graveyard_to_hand(inst)


## One-line log/UI text.
func describe() -> String:
	if to_battlefield_mode:
		return "returns %s to the battlefield" % target_spec.description
	return "returns %s to its owner's hand" % target_spec.description
