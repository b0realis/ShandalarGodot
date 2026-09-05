class_name SetBasePowerToughnessEffect
extends EffectBase
## "Target creature has base power [and toughness] N until end of turn."
## — Island of Wak-Wak and Singing Tree (power 0), Sorceress Queen (0/2).
##
## Registers a floating base-P/T set in game.continuous, applied in
## CR 613 layer 7b: after animations AND after the base-P/T-setting static
## abilities, but before counters and until-EOT pumps. Both halves of that
## matter — running after the statics is what lets Island of Wak-Wak ground
## a Nightmare whose own characteristic-defining ability says otherwise
## (a one-shot has the later timestamp within the sublayer), and running
## before the pumps is what lets a Giant Growth cast afterwards still add
## its +3/+3 on top.
##
## Pass -1 for a half that should not change (Island of Wak-Wak sets only
## the power).

## Base power to set, or -1 to leave power alone.
var power: int

## Base toughness to set, or -1 to leave toughness alone.
var toughness: int


func _init(p_power: int, p_toughness: int = -1, spec: TargetSpec = null) -> void:
	power = p_power
	toughness = p_toughness
	target_spec = spec if spec != null else TargetSpec.creature()


## Registers the set with game.continuous
## ([method ContinuousEffects.add_until_eot_base_pt]) and recalculates, so
## the target's live cur_power/cur_toughness are re-derived from the
## rewritten base. The log line reads the values back AFTER the recalculation
## so it reports what the creature actually became, counters and anthems
## included, not the raw numbers this effect asked for.
func resolve(game: MtgGame, source: CardInstance, _controller: int, target: TargetRef,
		_x_value: int = 0) -> void:
	var inst := game.find_instance(target.instance_id)
	if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.continuous.add_until_eot_base_pt(inst.id, power, toughness)
	game.recalculate()
	game.log_line("%s sets %s to base %d/%d until end of turn" % [
		source.data.card_name, inst.data.card_name, inst.cur_power, inst.cur_toughness])


## One-line log/UI text.
func describe() -> String:
	if toughness < 0:
		return "%s has base power %d until end of turn" % [target_spec.description, power]
	return "%s has base power and toughness %d/%d until end of turn" % [
		target_spec.description, power, toughness]
