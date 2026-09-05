class_name UntapEffect
extends EffectBase
## "Untap target [permanent]." — Ley Druid, Candelabra of Tawnos, and the
## untap half of Twiddle-style effects.
##
## Untapping is NOT restricted by the untap-step caps (Winter Orb, Smoke):
## those gate MtgGame's untap STEP, while this is an effect untapping a
## permanent, which is exactly why Candelabra of Tawnos beats an Orb.


func _init(spec: TargetSpec = null) -> void:
	target_spec = spec if spec != null else TargetSpec.new(
		TargetSpec.Kind.PERMANENT, "target permanent")


## Clears CardInstance.tapped through MtgGame.untap_permanent (which also
## fires the BECAME_UNTAPPED event and recalculates).
func resolve(game: MtgGame, _source: CardInstance, _controller: int, target: TargetRef,
		_x_value: int = 0) -> void:
	var inst := game.find_instance(target.instance_id)
	if inst != null:
		game.untap_permanent(inst)


## One-line log/UI text.
func describe() -> String:
	return "untaps %s" % target_spec.description
