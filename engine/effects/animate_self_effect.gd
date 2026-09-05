class_name AnimateSelfEffect
extends EffectBase
## "[This permanent] becomes an N/N [subtype] [extra types] creature until
## end of turn. It's still a [what it was]." — Mishra's Factory, and later
## every animating land/artifact in the pool (Stalking Stones' ancestors).
##
## Resolving registers a TYPE-CHANGING until-end-of-turn effect with
## game.continuous (see add_until_eot_animation): the pipeline ADDS the
## given type flags and subtypes to the object's live cur_types /
## cur_subtypes and SETS base power/toughness — before counters, statics
## and pumps, so a Giant Growth on an animated Factory works. The printed
## types are untouched ("it's still a land"); cleanup reverts everything.
##
## Combat legality falls out of the live-type sweep: summoning_sick is set
## on EVERY entering permanent, so a Factory played this turn can animate
## but not attack (CR 302.6 — the classic judge call, answered correctly).

## Type flags to ADD (usually CREATURE, plus ARTIFACT for the Factory).
var add_types: int
## The animated form's base power/toughness (SET, not added).
var set_power: int
var set_toughness: int
## Subtypes to ADD (lowercase, e.g. ["assembly-worker"]).
var add_subtypes: Array = []

## When true the animation expires when the combat phase ends, not at
## cleanup — Jade Statue's "until end of combat" (CR 700.5).
var combat_duration: bool = false


func _init(p_add_types: int, p_power: int, p_toughness: int,
		p_subtypes: Array = []) -> void:
	add_types = p_add_types
	set_power = p_power
	set_toughness = p_toughness
	for s in p_subtypes:
		add_subtypes.append(String(s).to_lower())


## Fluent: expire at end of combat instead of end of turn.
func until_end_of_combat() -> AnimateSelfEffect:
	combat_duration = true
	return self


## Registers the animation with game.continuous
## ([method ContinuousEffects.add_until_eot_animation]) and recalculates, so
## the source's live cur_types/cur_subtypes/cur_power/cur_toughness change
## on the spot. Nothing is written to the instance directly — the pipeline
## re-derives it on every pass, which is what makes the animation survive
## unrelated recalculations and vanish exactly on expiry.
func resolve(game: MtgGame, source: CardInstance, _controller: int, _target: TargetRef,
		_x_value: int = 0) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return   # left the battlefield in response — nothing to animate
	game.continuous.add_until_eot_animation(source.id, add_types,
		set_power, set_toughness, add_subtypes, combat_duration)
	game.log_line("%s becomes a %d/%d creature until end of %s" % [
		source.data.card_name, set_power, set_toughness,
		"combat" if combat_duration else "turn"])
	game.recalculate()


## One-line log/UI text.
func describe() -> String:
	return "becomes a %d/%d creature until end of %s" % [
		set_power, set_toughness, "combat" if combat_duration else "turn"]
