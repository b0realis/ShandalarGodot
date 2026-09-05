extends CardScript
## Stone Giant — {2}{R}{R} — Creature — Giant — 3/4 — (2ed, uncommon)
## Oracle: {T}: Target creature you control with toughness less than this
##         creature's power gains flying until end of turn. Destroy that
##         creature at the beginning of the next end step.
##
## Implementation: a source-aware target filter (yours, and toughness <
## the Giant's LIVE power) plus a card-local effect that grants flying
## and condemns the thrown creature with MtgGame.doom_at_next_end_step —
## a destruction, so a regeneration shield saves it. Four evasive damage
## for a turn, at the cost of the body.


func build() -> CardData:
	var spec := TargetSpec.creature(
		"target creature you control with toughness less than Stone Giant's power")
	spec.with_source_filter(_throwable)
	return CardData.new("Stone Giant", "{2}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(3, 4) \
		.with_subtypes(["giant"]) \
		.activated(ActivatedAbility.new(
			"", true, [ThrowEffect.new(spec)],
			"{T}: Target creature you control with toughness less than Stone Giant's "
			+ "power gains flying until end of turn. Destroy that creature at the "
			+ "beginning of the next end step.")) \
		.oracle("{T}: Target creature you control with toughness less than this "
			+ "creature's power gains flying until end of turn. Destroy that creature "
			+ "at the beginning of the next end step.")


static func _throwable(_game: MtgGame, source: CardInstance, inst: CardInstance) -> bool:
	return inst.controller_id == source.controller_id \
		and inst.cur_toughness < source.cur_power


class ThrowEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_pump(inst.id, 0, 0, [Mtg.Keyword.FLYING])
		game.recalculate()
		game.doom_at_next_end_step(inst)

	func describe() -> String:
		return "throws target creature: it gains flying, then dies at end of turn"
