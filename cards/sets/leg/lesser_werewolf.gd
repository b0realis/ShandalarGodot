extends CardScript
## Lesser Werewolf — {3}{B} — Creature — Werewolf — 2/4 — (leg, uncommon)
## Oracle: {B}: If this creature's power is 1 or more, it gets -1/-0 until
##         end of turn and put a -0/-1 counter on target creature blocking
##         or blocked by this creature. Activate only during the declare
##         blockers step.
##
## Implementation: a repeatable, permanent shrink ray with a self-imposed
## limit — the Werewolf spends its own power one point at a time, so with
## its printed 2 only two activations can RESOLVE with effect in a turn, and
## the "-0/-1" it hands out is a real COUNTER that never wears off. The
## counter's NAME is parsed by the continuous pipeline
## (ContinuousEffects._parse_pt_counter), which is why no static is needed
## to make it stick.
##
## "If this creature's power is 1 or more" is an IF clause inside the
## effect, so it is judged as the ability RESOLVES (CR 608.2c) — a player
## can hold priority and activate four times at power 2, but the third and
## fourth find power 0 and do nothing (Manalink's card_lesser_werewolf
## likewise tests get_power() > 0 at EVENT_RESOLVE_ACTIVATION). The
## ActivatedAbility.only_if pre-check is a courtesy that stops the obvious
## waste of {B} before it is paid; the check in MaulEffect.resolve is the
## one the rules require. The step restriction is
## ActivatedAbility.during_step, enforced before the {B} is paid (CR
## 602.5). "Blocking or blocked by this creature" is a TARGETING
## restriction and lives in the TargetSpec.


func build() -> CardData:
	var engaged := TargetSpec.creature("target creature blocking or blocked by this creature")
	engaged.with_source_filter(_engaged_with_source)
	return CardData.new("Lesser Werewolf", "{3}{B}", Mtg.CardType.CREATURE) \
		.pt(2, 4) \
		.with_subtypes(["werewolf"]) \
		.activated(ActivatedAbility.new(
			"{B}", false, [MaulEffect.new(engaged)],
			"{B}: This creature gets -1/-0 until end of turn and puts a -0/-1 counter on target creature blocking or blocked by it.") \
			.during_step(Mtg.Step.DECLARE_BLOCKERS) \
			.only_if(_has_power_left)) \
		.oracle("{B}: If this creature's power is 1 or more, it gets -1/-0 until end of turn "
			+ "and put a -0/-1 counter on target creature blocking or blocked by this "
			+ "creature. Activate only during the declare blockers step.")


static func _has_power_left(_game: MtgGame, source: CardInstance) -> String:
	if source.cur_power < 1:
		return "%s has no power left to spend" % source.data.card_name
	return ""


static func _engaged_with_source(game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	if game.combat.attackers.has(source.id):
		return game.combat.blockers_of_band(
			game.combat.band_of(source.id)).has(inst.id)
	if game.combat.blocks.has(source.id):
		return game.combat.opposing_attackers(source.id).has(inst.id)
	return false


class MaulEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var victim := game.find_instance(target.instance_id)
		if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD:
			return
		# "If this creature's power is 1 or more" is judged NOW, as the
		# ability resolves (CR 608.2c), not when it was activated: earlier
		# activations in the same batch may already have spent the power.
		# A Werewolf that left the battlefield is read by last-known
		# information (CR 113.7a).
		var power := source.cur_power if source.zone == Mtg.Zone.BATTLEFIELD \
			else source.last_power
		if power < 1:
			return
		# The self-shrink is paid even if the victim slipped away: the
		# ability would only be countered if EVERY target were illegal
		# (CR 608.2b), and the engine already checked that above.
		if source.zone == Mtg.Zone.BATTLEFIELD:
			game.continuous.add_until_eot_pump(source.id, -1, 0)
		game.add_counters(victim, "-0/-1", 1)
		game.recalculate()

	func describe() -> String:
		return "-1/-0 to itself and a -0/-1 counter on %s" % target_spec.description
