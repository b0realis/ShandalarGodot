extends CardScript
## Berserk — {G} — Instant — (2ed, uncommon)
## Oracle: Cast this spell only before the combat damage step. Target
##         creature gains trample and gets +X/+0 until end of turn, where
##         X is its power. At the beginning of the next end step, destroy
##         that creature if it attacked this turn.
##
## Implementation: one card-local effect — it reads the target's LIVE
## power, doubles it with a floating pump, grants TRAMPLE, and condemns it
## with MtgGame.doom_at_next_end_step(only_if_attacked = true). The
## "if it attacked this turn" clause belongs to the DELAYED TRIGGER, so it
## is evaluated at the end step, not at resolution: a Berserk cast in the
## precombat main phase still kills the creature that goes on to attack.
##
## The printed casting restriction ("only before the combat damage step")
## is enforced through CardData.castable_only_when.


func build() -> CardData:
	return CardData.new("Berserk", "{G}", Mtg.CardType.INSTANT) \
		.castable_only_when(_before_combat_damage) \
		.spell(BerserkEffect.new()) \
		.oracle("Cast this spell only before the combat damage step. Target creature "
			+ "gains trample and gets +X/+0 until end of turn, where X is its power. "
			+ "At the beginning of the next end step, destroy that creature if it "
			+ "attacked this turn.")


static func _before_combat_damage(game: MtgGame, _pid: int) -> String:
	if Mtg.STEP_ORDER.find(game.current_step()) \
			>= Mtg.STEP_ORDER.find(Mtg.Step.COMBAT_DAMAGE):
		return "cast Berserk only before the combat damage step"
	return ""


class BerserkEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_pump(inst.id, inst.cur_power, 0,
			[Mtg.Keyword.TRAMPLE])
		game.recalculate()
		game.log_line("%s berserks %s (now %d/%d)" % [
			source.data.card_name, inst.data.card_name, inst.cur_power, inst.cur_toughness])
		game.doom_at_next_end_step(inst, true)

	func describe() -> String:
		return "target creature gains trample and doubles its power; it dies if it attacked"
