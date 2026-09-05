class_name GrantLandwalkEffect
extends EffectBase
## "Target creature gains <type>walk until end of turn." (Part Water's
## islandwalk, War Barge's, Wormwood Treefolk's swampwalk.)
##
## Registers a floating grant in the continuous pipeline
## ([method ContinuousEffects.add_until_eot_landwalk]) — the same list the
## pipeline applies before ability losses, so a Hammerheim aimed at the same
## creature later in the turn still strips it.

## Lowercase land subtypes granted ("island", "forest"...).
var land_types: Array[String] = []

## Expire at end of combat instead of at cleanup (CR 700.5).
var until_combat: bool = false


func _init(p_types: Array, spec: TargetSpec = null) -> void:
	for t in p_types:
		land_types.append(String(t).to_lower())
	target_spec = spec if spec != null else TargetSpec.creature()


## Fluent: the grant lasts only until end of combat.
func until_end_of_combat() -> GrantLandwalkEffect:
	until_combat = true
	return self


## Registers the grant with game.continuous
## ([method ContinuousEffects.add_until_eot_landwalk]) and recalculates, so
## the pipeline rebuilds the target's cur_landwalk. The battlefield check is
## the "target left in response" guard: a creature bounced before this
## resolves must not carry the grant back when it returns (CR 400.7).
func resolve(game: MtgGame, _source: CardInstance, _controller: int, target: TargetRef,
		_x_value: int = 0) -> void:
	var inst := game.find_instance(target.instance_id)
	if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.continuous.add_until_eot_landwalk(inst.id, land_types, until_combat)
	game.recalculate()


## One-line log/UI text.
func describe() -> String:
	var names := PackedStringArray()
	for t in land_types:
		names.append("%swalk" % t)
	return "%s gains %s until end of turn" % [
		target_spec.description if target_spec else "?", ", ".join(names)]
