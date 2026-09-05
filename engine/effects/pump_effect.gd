class_name PumpEffect
extends EffectBase
## "Target creature gets +P/+T [and gains keywords] until end of turn."
##
## This is the bridge from one-shot resolution into the continuous-effects
## system: resolving registers a floating effect with game.continuous, which
## re-applies it on every recalculation until the cleanup step expires it.
## (Giant Growth is exactly [code]PumpEffect.new(3, 3)[/code].)

## Power/toughness delta. Negative is fine and common — Pradesh Gypsies is
## -2/-0, Ghosts of the Damned -1/-0.
var power: int
var toughness: int

## Keywords (Mtg.Keyword values) the creature also gains for the duration.
## A 0/0 pump carrying one keyword is the whole card for Jump (flying) and
## Helm of Chatzuk (banding).
var granted_keywords: Array[int] = []

## When true the pump applies to the effect's own source instead of a
## target — the "firebreathing" pattern ("{R}: Shivan Dragon gets +1/+0
## until end of turn"). Set via [method self_buff].
var self_mode: bool = false

## When true the POWER half equals the spell's X (Howl from Beyond).
var use_x_power: bool = false


func _init(p_power: int, p_toughness: int, p_keywords: Array = []) -> void:
	power = p_power
	toughness = p_toughness
	for k in p_keywords:
		granted_keywords.append(k)
	target_spec = TargetSpec.creature()


## Fluent: buff the source itself (no target) — Shivan Dragon, Frozen Shade.
func self_buff() -> PumpEffect:
	self_mode = true
	target_spec = null
	return self


## Fluent: the power boost is X (Howl from Beyond).
func x_power() -> PumpEffect:
	use_x_power = true
	return self


## Registers a floating pump with game.continuous
## ([method ContinuousEffects.add_until_eot_pump]) and recalculates. The
## pipeline applies it AFTER counters and every base-P/T setter, so a Giant
## Growth adds on top of a Sorceress Queen's 0/2 rather than being erased
## by it — and MtgGame.recalculate is what re-derives cur_power here, never
## this effect.
func resolve(game: MtgGame, source: CardInstance, _controller: int, target: TargetRef,
		x_value: int = 0) -> void:
	var affected_id := source.id if self_mode else target.instance_id
	var affected := game.find_instance(affected_id)
	if affected == null or affected.zone != Mtg.Zone.BATTLEFIELD:
		return   # source left the battlefield before its own buff resolved
	var power_boost := x_value if use_x_power else power
	game.continuous.add_until_eot_pump(affected_id, power_boost, toughness, granted_keywords)
	game.log_line("%s gives %s %+d/%+d until end of turn" % [
		source.data.card_name, affected, power_boost, toughness])
	game.recalculate()


## One-line log/UI text. Assumes a target — [method self_buff] abilities
## carry their own ActivatedAbility.text instead.
func describe() -> String:
	return "%s gets %+d/%+d until end of turn" % [
		target_spec.description, power, toughness]
