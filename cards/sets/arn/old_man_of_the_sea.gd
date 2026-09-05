extends CardScript
## Old Man of the Sea — {1}{U}{U} — Creature — Djinn — 2/3 — (arn, rare)
## Oracle: You may choose not to untap this creature during your untap step.
##         {T}: Gain control of target creature with power less than or
##         equal to this creature's power for as long as this creature
##         remains tapped and that creature's power remains less than or
##         equal to this creature's power.
##
## Implementation: a control LEASH with BOTH of the printed conditions —
## `gain_control_leashed(prize, source, needs_tapped, power_capped)` — plus
## with_may_skip_untap, so the Old Man automatically stays tapped while he
## is holding something. The target filter compares LIVE power against his
## own, and so does the state-based action that keeps the leash: pumping
## the stolen creature past his power hands it straight back, and so does
## shrinking him.
##
## "You may choose not to untap" is the controller's call, asked in their
## untap step (MtgGame._untap_step, `@ISLAND_FISH_JASCONIUS`'s two-line
## form: "Untap <name>." / "Don't untap."); the heuristic keeps it tapped
## while it is sustaining something and untaps it otherwise.


func build() -> CardData:
	# The bound is the Old Man's LIVE power, not the printed 2 — a pumped
	# Old Man reaches further; TargetSpec has no describe callback, so the
	# description names the rule rather than a number.
	var spec := TargetSpec.creature(
		"target creature with power no greater than Old Man of the Sea's")
	spec.with_source_filter(_weak_enough)
	return CardData.new("Old Man of the Sea", "{1}{U}{U}", Mtg.CardType.CREATURE) \
		.pt(2, 3) \
		.with_subtypes(["djinn"]) \
		.with_may_skip_untap() \
		.activated(ActivatedAbility.new(
			"", true, [HoldEffect.new(spec)],
			"{T}: Gain control of target creature with power less than or equal to "
			+ "Old Man of the Sea's power for as long as he remains tapped and "
			+ "that creature's power remains less than or equal to his.")) \
		.oracle("You may choose not to untap this creature during your untap step.\n"
			+ "{T}: Gain control of target creature with power less than or equal to "
			+ "this creature's power for as long as this creature remains tapped and "
			+ "that creature's power remains less than or equal to this creature's power.")


static func _weak_enough(_game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	return inst.cur_power <= source.cur_power


class HoldEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var prize := game.find_instance(target.instance_id)
		if prize != null and source.zone == Mtg.Zone.BATTLEFIELD:
			game.gain_control_leashed(prize, source, true, true)

	func describe() -> String:
		return "gain control of %s while this stays tapped" % target_spec.description
