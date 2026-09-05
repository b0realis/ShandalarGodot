extends CardScript
## Telekinesis — {U}{U} — Instant — (leg, rare)
## Oracle: Tap target creature. Prevent all combat damage that would be
##         dealt by that creature this turn. It doesn't untap during its
##         controller's next two untap steps.
##
## Implementation: one card-local effect doing all three halves (the
## printed card has a single target the sentences share) — tap, a
## floating combat-damage prevention, and two more CardInstance.skip_untaps,
## which the untap step decrements. Three turns off the board for two
## mana at instant speed; a second copy adds two more untap steps.


func build() -> CardData:
	return CardData.new("Telekinesis", "{U}{U}", Mtg.CardType.INSTANT) \
		.spell(TelekinesisEffect.new()) \
		.oracle("Tap target creature. Prevent all combat damage that would be dealt "
			+ "by that creature this turn. It doesn't untap during its controller's "
			+ "next two untap steps.")


class TelekinesisEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.tap_permanent(inst)
		# Two MORE untap steps: a second Telekinesis is an independent
		# effect and they add up (CR 614.5-style stacking), so never assign.
		inst.skip_untaps += 2
		game.continuous.add_until_eot_combat_prevention(inst.id, true, false)
		game.recalculate()

	func describe() -> String:
		return "taps target creature, silences it and locks it down for two untaps"
