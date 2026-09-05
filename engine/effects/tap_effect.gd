class_name TapEffect
extends EffectBase
## "Tap target [permanent]." — Icy Manipulator's payload.
##
## Pure state change through MtgGame.tap_permanent (no untap-step skip —
## the target untaps normally on its controller's next untap step).


func _init(spec: TargetSpec = null) -> void:
	target_spec = spec if spec != null else TargetSpec.new(
		TargetSpec.Kind.PERMANENT, "target permanent")


## Sets CardInstance.tapped through MtgGame.tap_permanent, which is also
## what fires the BECAME_TAPPED event and runs the cheap tap-only
## recalculation. Tapping an already-tapped permanent is a no-op there, so
## Icy Manipulator aimed at a tapped creature simply does nothing.
func resolve(game: MtgGame, _source: CardInstance, _controller: int, target: TargetRef,
		_x_value: int = 0) -> void:
	var inst := game.find_instance(target.instance_id)
	if inst != null:
		game.tap_permanent(inst)


## One-line log/UI text.
func describe() -> String:
	return "taps %s" % target_spec.description
