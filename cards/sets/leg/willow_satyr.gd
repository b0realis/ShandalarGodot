extends CardScript
## Willow Satyr — {2}{G}{G} — Creature — Satyr — 1/1 — (leg, rare)
## Oracle: You may choose not to untap this creature during your untap step.
##         {T}: Gain control of target legendary creature for as long as
##         you control this creature and this creature remains tapped.
##
## Implementation: Rubinia's leash narrowed to LEGENDARY creatures — a
## four-mana answer to any Elder Dragon or Legends bomb, which in this
## set is most of the good cards.
##
## "You may choose not to untap" is the controller's call, asked in their
## untap step (MtgGame._untap_step, `@ISLAND_FISH_JASCONIUS`'s two-line
## form: "Untap <name>." / "Don't untap."); the heuristic keeps it tapped
## while it is sustaining something and untaps it otherwise.


func build() -> CardData:
	var spec := TargetSpec.creature("target legendary creature", _is_legendary)
	return CardData.new("Willow Satyr", "{2}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["satyr"]) \
		.with_may_skip_untap() \
		.activated(ActivatedAbility.new(
			"", true, [HoldEffect.new(spec)],
			"{T}: Gain control of target legendary creature for as long as you "
			+ "control Willow Satyr and it remains tapped.")) \
		.oracle("You may choose not to untap this creature during your untap step.\n"
			+ "{T}: Gain control of target legendary creature for as long as you "
			+ "control this creature and this creature remains tapped.")


static func _is_legendary(inst: CardInstance) -> bool:
	return (inst.data.supertypes & Mtg.Supertype.LEGENDARY) != 0


class HoldEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var prize := game.find_instance(target.instance_id)
		if prize != null and source.zone == Mtg.Zone.BATTLEFIELD:
			game.gain_control_leashed(prize, source, true)

	func describe() -> String:
		return "gain control of target legendary creature while this stays tapped"
