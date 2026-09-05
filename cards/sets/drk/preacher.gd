extends CardScript
## Preacher — {1}{W}{W} — Creature — Human Cleric — 1/1 — (drk, rare)
## Oracle: You may choose not to untap this creature during your untap step.
##         {T}: For as long as this creature remains tapped, gain control
##         of target creature of an opponent's choice they control.
##
## Implementation: the creature is a TARGET the OPPONENT chooses
## (TargetSpec.opponent_chooses): the printed "of an opponent's choice"
## is theirs to make, and they make it as the ability is activated (CR
## 601.2c), through the same hold that asks a human which body a
## sacrifice cost eats — so the ability can't be activated with no
## creature on the other side, a creature with shroud or protection from
## white is not on their list, and the ability fizzles if what they named
## has left by resolution. The list is ordered worst-first from the
## VICTIM's point of view (they choose what to give up), and that first
## entry is what their heuristic hands over. What they named is then
## leashed to the tapped Preacher: a 1/1 that permanently borrows a
## creature — as long as it never untaps.
##
## "You may choose not to untap" is the controller's call, asked in their
## untap step (MtgGame._untap_step, `@ISLAND_FISH_JASCONIUS`'s two-line
## form: "Untap <name>." / "Don't untap."); the heuristic keeps it tapped
## while it is sustaining something and untaps it otherwise.
##
## "For as long as this creature remains tapped": a Preacher untapped in
## response has a duration that ended before the effect began, so the
## effect does nothing (CR 611.2b).


func build() -> CardData:
	return CardData.new("Preacher", "{1}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "cleric"]) \
		.with_may_skip_untap() \
		.activated(ActivatedAbility.new(
			"", true, [PreachEffect.new()],
			"{T}: For as long as Preacher remains tapped, gain control of target "
			+ "creature of an opponent's choice they control.")) \
		.oracle("You may choose not to untap this creature during your untap step.\n"
			+ "{T}: For as long as this creature remains tapped, gain control of "
			+ "target creature of an opponent's choice they control.")


class PreachEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature(
				"target creature of an opponent's choice they control") \
			.with_source_filter(PreachEffect._theirs) \
			.opponent_chooses(PreachEffect._least_missed_first,
				"Select target creature.")

	static func _theirs(_game: MtgGame, source: CardInstance,
			inst: CardInstance) -> bool:
		return source == null or inst.controller_id != source.controller_id

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		if source.zone != Mtg.Zone.BATTLEFIELD or not source.tapped:
			return   # CR 611.2b: the "remains tapped" duration already ended
		var chosen := game.find_instance(target.instance_id)
		if chosen == null or chosen.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.gain_control_leashed(chosen, source, true)

	## THEIR order: cheapest body first, then the smallest — a card-local
	## stand-in for "which creature would its controller miss least".
	static func _least_missed_first(game: MtgGame, _source: CardInstance,
			a_ref: TargetRef, b_ref: TargetRef) -> bool:
		var a := game.find_instance(a_ref.instance_id)
		var b := game.find_instance(b_ref.instance_id)
		var mv_a := a.data.cost.mana_value()
		var mv_b := b.data.cost.mana_value()
		if mv_a != mv_b:
			return mv_a < mv_b
		var va := a.cur_power + a.cur_toughness
		var vb := b.cur_power + b.cur_toughness
		if va != vb:
			return va < vb
		return a.id < b.id

	func describe() -> String:
		return "gain control of a creature of an opponent's choice"
