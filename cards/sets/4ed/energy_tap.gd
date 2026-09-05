extends CardScript
## Energy Tap — {U} — Sorcery — (4ed, common)
## Oracle: Tap target untapped creature you control. If you do, add an
##         amount of {C} equal to that creature's mana value.
##
## Implementation: a card-local effect with a source-aware target filter
## (untapped, and yours). The mana lands in the pool at resolution — so
## it must be spent in the same step, exactly like any other ritual.


func build() -> CardData:
	var spec := TargetSpec.creature("target untapped creature you control")
	spec.with_source_filter(_yours_and_untapped)
	return CardData.new("Energy Tap", "{U}", Mtg.CardType.SORCERY) \
		.spell(TapForManaEffect.new(spec)) \
		.oracle("Tap target untapped creature you control. If you do, add an amount "
			+ "of {C} equal to that creature's mana value.")


static func _yours_and_untapped(_game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	return not inst.tapped and inst.controller_id == source.controller_id


class TapForManaEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD or inst.tapped:
			return
		game.tap_permanent(inst)
		var n := inst.data.cost.mana_value()
		if n > 0:
			game.players[controller].mana_pool.add(Mtg.ManaColor.C, n)

	func describe() -> String:
		return "taps target untapped creature you control for its mana value in {C}"
