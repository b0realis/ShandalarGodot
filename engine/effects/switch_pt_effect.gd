class_name SwitchPowerToughnessEffect
extends EffectBase
## "Switch target creature's power and toughness until end of turn."
## (Transmutation.)
##
## Registers a floating switch in game.continuous, which applies it in the
## FINAL sublayer of the P/T pipeline (CR 613.4e) — so a Giant Growth cast
## afterwards pumps the already-switched values, and a second switch on the
## same creature restores the original orientation.


func _init(spec: TargetSpec = null) -> void:
	target_spec = spec if spec != null else TargetSpec.creature()


## Registers the switch with game.continuous
## ([method ContinuousEffects.add_until_eot_pt_switch]) and recalculates. The
## switch is never applied to the instance directly — it has to be re-derived
## last on every pass, or a later anthem would be swapped along with it.
func resolve(game: MtgGame, source: CardInstance, _controller: int, target: TargetRef,
		_x_value: int = 0) -> void:
	var inst := game.find_instance(target.instance_id)
	if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.continuous.add_until_eot_pt_switch(inst.id)
	game.recalculate()
	game.log_line("%s switches %s to %d/%d until end of turn" % [
		source.data.card_name, inst.data.card_name, inst.cur_power, inst.cur_toughness])


## One-line log/UI text.
func describe() -> String:
	return "switches %s's power and toughness until end of turn" % target_spec.description
