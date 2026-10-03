class_name PreventDamageEffect
extends EffectBase
## "Prevent the next N damage that would be dealt to any target this turn."
## — Healing Salve's second mode, Samite Healer, Death Ward's cousin.
##
## Resolving adds N to the target's prevention pool: CardInstance.prevention
## for a creature, MtgPlayer.damage_prevention for a player. MtgGame's
## deal_damage consumes the pool point for point BEFORE damage lands;
## cleanup zeroes both pools (prevention is this-turn only, CR 615).
##
## Distinct from PreventDamageShieldEffect (CoP): that one is a one-shot
## whole-event shield keyed to a source color; this one is a plain amount.

## How much damage to prevent.
var amount: int

## When true the amount equals the spell's X (Guardian Angel, Alabaster
## Potion) and [member amount] is ignored.
var use_x: bool = false

## When true the pool goes to the effect's CONTROLLER, untargeted
## ("prevent ... dealt to you" — Conservator). target_spec stays null.
var controller_mode: bool = false


func _init(p_amount: int) -> void:
	amount = p_amount
	is_damage_prevention = true   # legal in the 1997 window (§6.8)


## Fluent: target anything ("any target" — creature or player).
func any_target() -> PreventDamageEffect:
	target_spec = TargetSpec.any_target()
	return self


## Fluent: target a creature only.
func target_creature(desc: String = "", filter: Callable = Callable()) -> PreventDamageEffect:
	target_spec = TargetSpec.creature(desc, filter)
	return self


## Fluent: the prevented amount is the spell's X.
func x_amount() -> PreventDamageEffect:
	use_x = true
	return self


## Fluent: "Prevent the next [param total] damage that would be dealt this
## turn to any number of targets, divided as you choose" (Remedy) — CR
## 601.2d: the division is announced with the targets (each gets at least
## 1, the shares sum to the total, [TargetPlan] checks it) and each target's
## pool receives its own share ([member TargetRef.amount]). Pass -1 to
## divide the spell's X. Any target unless a spec was set first.
func divided(total: int) -> PreventDamageEffect:
	divided_among(total)
	if target_spec == null:
		target_spec = TargetSpec.any_target()
	return self


## A DIVIDED prevention hands each target its own share (locked in at cast,
## CR 601.2d); an undivided one falls back to "the same amount, once per
## target".
func resolve_multi(game: MtgGame, source: CardInstance, controller: int,
		targets: Array, x_value: int = 0) -> void:
	if divided_amount(x_value) <= 0:
		super(game, source, controller, targets, x_value)
		return
	for ref in targets:
		_prevent_into(game, source, ref, int(ref.amount))


## Fluent: shield the controller, no target ("...dealt to you").
func to_controller() -> PreventDamageEffect:
	controller_mode = true
	target_spec = null
	return self


## When true the pool goes to the effect's own SOURCE, untargeted
## ("prevent the next 1 damage that would be dealt to THIS CREATURE" —
## Rock Hydra). target_spec stays null.
var source_mode: bool = false

## Fluent: shield the source itself, no target.
func to_source() -> PreventDamageEffect:
	source_mode = true
	target_spec = null
	return self


## "Until end of turn, you may pay {1} any time you could cast an instant.
## If you do, prevent the next 1 damage that would be dealt to that
## permanent or player this turn" (Guardian Angel). Granted on the seat
## by MtgGame.grant_paid_prevention, spent through
## MtgGame.pay_for_prevention — and granted even when X is 0, since the
## rider is its own sentence.
var paid_rider: bool = false

## Fluent: add Guardian Angel's "pay {1} for 1 more" rider.
func with_paid_rider() -> PreventDamageEffect:
	paid_rider = true
	return self


## Adds to a prevention POOL — MtgPlayer.damage_prevention for a player,
## CardInstance.prevention for a creature. Both are plain counters that
## MtgGame.deal_damage draws down before damage lands; cleanup zeroes them.
## A creature's pool also remembers WHICH CARD filled it
## ([member CardInstance.prevention_source]) so the table can show it.
## This is the one effect family that writes instance state directly rather
## than going through an MtgGame helper, because a prevention pool is inert
## bookkeeping: nothing triggers on it and no state-based action reads it.
func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef,
		x_value: int = 0) -> void:
	var n := x_value if use_x else amount
	if paid_rider and target != null:
		game.grant_paid_prevention(controller, target, source.data.card_name,
			source.data)
	if n <= 0:
		return
	if source_mode:
		if not game.is_present(source):   # gone, or phased out (CR 702.26e)
			return
		source.prevention += n
		source.prevention_source = source.data
		game.log_line("%s will prevent the next %d damage to itself this turn" % [
			source.data.card_name, n])
		return
	if controller_mode:
		game.players[controller].damage_prevention += n
		game.log_line("%s will prevent the next %d damage to %s this turn" % [
			source.data.card_name, n, game.players[controller].player_name])
		return
	_prevent_into(game, source, target, n)


## Add [param n] to [param target]'s prevention pool — the player's or the
## creature's (see [method resolve]).
func _prevent_into(game: MtgGame, source: CardInstance, target: TargetRef,
		n: int) -> void:
	if target == null or n <= 0:
		return
	if target.is_player:
		game.players[target.player_id].damage_prevention += n
		game.log_line("%s will prevent the next %d damage to %s this turn" % [
			source.data.card_name, n, game.players[target.player_id].player_name])
	else:
		var inst := game.find_instance(target.instance_id)
		if not game.is_present(inst):   # CR 702.26e
			return
		inst.prevention += n
		# WHO SHIELDED IT, for the table to draw behind the creature — see
		# [member CardInstance.prevention_source]. Inside a resolution, so
		# the journal already has the instance whole (_rec_resolution).
		inst.prevention_source = source.data
		game.log_line("%s will prevent the next %d damage to %s this turn" % [
			source.data.card_name, n, inst.data.card_name])


## One-line log/UI text.
func describe() -> String:
	var n := "X" if use_x else str(amount)
	if divided_total > 0 or divided_uses_x:
		return "prevents the next %s damage this turn to any number of targets, divided as you choose" \
			% ("X" if divided_uses_x else str(divided_total))
	if controller_mode:
		return "prevents the next %s damage to you this turn" % n
	var rider := "; then pay {1} any time for 1 more" if paid_rider else ""
	return "prevents the next %s damage to %s this turn%s" % [
		n, target_spec.description if target_spec else "?", rider]
