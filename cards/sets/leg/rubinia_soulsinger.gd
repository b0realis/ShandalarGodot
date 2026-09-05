extends CardScript
## Rubinia Soulsinger — {2}{G}{W}{U} — Legendary Creature — Faerie — 2/3 — (leg, rare)
## Oracle: You may choose not to untap Rubinia Soulsinger during your
##         untap step.
##         {T}: Gain control of target creature for as long as you control
##         Rubinia Soulsinger and Rubinia Soulsinger remains tapped.
##
## Implementation: the Old Man of the Sea leash with no power limit at
## all — Rubinia takes anything, forever, as long as she stays tapped
## (which with_may_skip_untap makes automatic). The best of the Legends
## control creatures, and the reason Karakas exists.
##
## "You may choose not to untap" is the controller's call, asked in their
## untap step (MtgGame._untap_step, `@ISLAND_FISH_JASCONIUS`'s two-line
## form: "Untap <name>." / "Don't untap."); the heuristic keeps it tapped
## while it is sustaining something and untaps it otherwise.


func build() -> CardData:
	return CardData.new("Rubinia Soulsinger", "{2}{G}{W}{U}", Mtg.CardType.CREATURE) \
		.pt(2, 3) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["faerie"]) \
		.with_may_skip_untap() \
		.activated(ActivatedAbility.new(
			"", true, [HoldEffect.new(TargetSpec.creature())],
			"{T}: Gain control of target creature for as long as you control Rubinia "
			+ "Soulsinger and she remains tapped.")) \
		.oracle("You may choose not to untap Rubinia Soulsinger during your untap "
			+ "step.\n{T}: Gain control of target creature for as long as you control "
			+ "Rubinia Soulsinger and Rubinia Soulsinger remains tapped.")


class HoldEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var prize := game.find_instance(target.instance_id)
		if prize != null and source.zone == Mtg.Zone.BATTLEFIELD:
			game.gain_control_leashed(prize, source, true)

	func describe() -> String:
		return "gain control of target creature while this stays tapped"
