class_name MassPumpEffect
extends EffectBase
## "All creatures get +P/+T until end of turn" and its filtered variants
## ("Creatures you control get +0/+2" — Shield Wall; "All creatures get
## -1/-0" — Hell Swarm, Marsh Gas, Bone Flute).
##
## Untargeted, like every "all/each" effect — protection never applies.
## Each affected creature receives its own floating until-end-of-turn pump
## in game.continuous, so the boost survives further recalculation and
## expires at cleanup with everything else.
##
## Scope is chosen with the fluent helpers: default is every creature on
## the battlefield; [method yours_only] restricts to the effect's
## controller; [method with_filter] adds an arbitrary predicate on top
## (both compose).

## Power/toughness delta applied to every affected creature. Negative is
## normal here — Marsh Gas is -2/-0, Hell Swarm -1/-0.
var power: int
var toughness: int

## Keywords (Mtg.Keyword values) every affected creature also gains, for the
## same until-end-of-turn duration as the boost.
var granted_keywords: Array[int] = []

## When true only the effect controller's creatures are affected.
var controller_only: bool = false

## Optional extra predicate func(inst: CardInstance) -> bool.
var filter: Callable = Callable()

## Card-English scope for the log line ("all creatures").
var description: String = "all creatures"


func _init(p_power: int, p_toughness: int, p_description := "all creatures",
		p_keywords: Array = []) -> void:
	power = p_power
	toughness = p_toughness
	description = p_description
	for k in p_keywords:
		granted_keywords.append(k)


## Fluent: only creatures the effect's controller controls.
func yours_only() -> MassPumpEffect:
	controller_only = true
	return self


## Fluent: narrow the affected set further (e.g. "creatures with flying").
func with_filter(cb: Callable) -> MassPumpEffect:
	filter = cb
	return self


## "OTHER <X> creatures get …" (Orc General): skip the effect's own source.
## "Other" means other than this PERMANENT, not other than cards sharing
## its name — a second copy on the battlefield is still "other".
var skip_source: bool = false

## Fluent: exclude the effect's source from the affected set.
func excluding_source() -> MassPumpEffect:
	skip_source = true
	return self


## Registers ONE floating pump per matching creature with game.continuous
## ([method ContinuousEffects.add_until_eot_pump]), then recalculates. The
## affected set is fixed at resolution: a creature that enters afterwards
## gets nothing, which is the difference between this one-shot and an
## anthem's static ability (Crusade).
func resolve(game: MtgGame, source: CardInstance, controller: int, _target: TargetRef,
		_x_value: int = 0) -> void:
	for inst in game.all_battlefield():
		if not inst.is_creature():
			continue
		if skip_source and inst == source:
			continue
		if controller_only and inst.controller_id != controller:
			continue
		if filter.is_valid() and not filter.call(inst):
			continue
		game.continuous.add_until_eot_pump(inst.id, power, toughness, granted_keywords)
	game.log_line("%s: %s get %+d/%+d until end of turn" % [
		source.data.card_name, description, power, toughness])
	game.recalculate()


## One-line log/UI text.
func describe() -> String:
	return "%s get %+d/%+d until end of turn" % [description, power, toughness]
