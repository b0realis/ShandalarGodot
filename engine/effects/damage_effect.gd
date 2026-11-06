class_name DamageEffect
extends EffectBase
## "[Source] deals N damage to [target]." The workhorse of red.
##
## Damage to a player reduces life; damage to a creature is marked on it and
## a state-based action destroys it if the marks reach toughness. All of
## that mechanics lives in MtgGame.deal_damage — this effect only names the
## amount and the target.

## Fixed damage dealt. Ignored when [member use_x] is set.
var amount: int

## When true the damage equals the spell's X value (Fireball, Disintegrate)
## and [member amount] is ignored.
var use_x: bool = false
var x_bonus: int = 0
## Lava Burst: prevention/redirection is bypassed only for creature damage.
## A structural reading lets AI use the same rule without naming the card.
var unpreventable_to_creatures := false


func _init(p_amount: int) -> void:
	amount = p_amount


## Fluent: target anything ("any target").
func any_target() -> DamageEffect:
	target_spec = TargetSpec.any_target()
	return self


## Fluent: target a creature (optionally filtered).
func target_creature(desc: String = "", filter: Callable = Callable()) -> DamageEffect:
	target_spec = TargetSpec.creature(desc, filter)
	return self


## Fluent: target a PLAYER, optionally narrowed by a predicate
## [code]func(game, pid) -> bool[/code] ("target player who attacked this
## turn" — Fire and Brimstone).
func target_player(filter: Callable = Callable(), desc: String = "") -> DamageEffect:
	target_spec = TargetSpec.player()
	if filter.is_valid():
		target_spec.with_player_filter(filter)
	if desc != "":
		target_spec.description = desc
	return self


## Fluent: deal X damage instead of a fixed amount.
func x_damage() -> DamageEffect:
	use_x = true
	return self


## When true the damage hits the effect's CONTROLLER, untargeted
## ("[This] deals 5 damage to you" — Ashes to Ashes). No target_spec.
var controller_mode: bool = false

## Fluent: aim at the controller, no target.
func to_controller() -> DamageEffect:
	controller_mode = true
	target_spec = null
	return self


## Fluent: "N damage divided as you choose among any number of targets"
## (Pyrotechnics). Pass -1 to divide the spell's X instead (Fireball).
func divided(total: int) -> DamageEffect:
	divided_among(total)
	if target_spec == null:
		target_spec = TargetSpec.any_target()
	return self


## Hands the whole event to MtgGame.deal_damage, which marks it on the
## creature (or subtracts life) and applies prevention, protection and
## redirection. Nothing is mutated here — keeping every damage event on one
## code path is what makes Circles, Fogs and Veteran Bodyguard uniform.
func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef,
		x_value: int = 0) -> void:
	if controller_mode:
		target = TargetRef.player(controller)
	game.deal_damage(source, target, x_value + x_bonus if use_x else amount,
		false, Callable(), unpreventable_to_creatures)


## Divided damage hands each target its own share (locked in at cast time,
## CR 601.2d); everything else falls back to the base "once per target".
func resolve_multi(game: MtgGame, source: CardInstance, controller: int,
		targets: Array, x_value: int = 0) -> void:
	# Pack 10 E7: a total the source decided ([method EffectBase.divided_by])
	# was locked on the refs at announcement and is never read again.
	if divided_amount(x_value) <= 0 and not divided_count_fn.is_valid():
		super(game, source, controller, targets, x_value)
		return
	for ref in targets:
		game.deal_damage(source, ref, ref.amount, false, Callable(), unpreventable_to_creatures)


## One-line log/UI text.
func describe() -> String:
	if is_divided():
		var total := "X" if divided_uses_x or divided_count_fn.is_valid() else str(divided_total)
		return "deals %s damage divided as you choose among any number of targets" % total
	var n := "X" if use_x else str(amount)
	return "deals %s damage to %s" % [n, target_spec.description if target_spec else "?"]
