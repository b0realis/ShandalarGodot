extends CardScript
## City of Shadows — Land — (drk, rare)
## Oracle: {T}, Exile a creature you control: Put a storage counter on this
##         land.
##         {T}: Add {C} for each storage counter on this land.
##
## Implementation: the creature is a COST (ActivatedAbility.with_exile_of,
## new), so it goes as the ability is activated and nothing can be done
## about it in response; the counter arrives when the ability resolves.
##
## The two abilities share the same {T}, which is the whole design: a turn
## spent feeding the City is a turn it makes no mana, and the counters never
## go away, so it is a battery you fill with bodies. Storage counters are a
## plain (non-P/T) counter kind, invisible to the continuous pipeline.
##
## The mana half is a ManaAbility with a dynamic amount (the same rider the
## Urzatron uses), so it is stackless (CR 605.3) and its size is read live
## from the counters.


func build() -> CardData:
	return CardData.new("City of Shadows", "", Mtg.CardType.LAND) \
		.activated(ActivatedAbility.new("", true, [StoreEffect.new()],
			"{T}, Exile a creature you control: Put a storage counter on this land.") \
			.with_exile_of("creature you control", _is_creature)) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 1) \
			.with_dynamic_amount(_stored)) \
		.oracle("{T}, Exile a creature you control: Put a storage counter on this "
			+ "land.\n{T}: Add {C} for each storage counter on this land.")


static func _is_creature(inst: CardInstance) -> bool:
	return inst.is_creature()


static func _stored(_game: MtgGame, source: CardInstance) -> int:
	return int(source.counters.get("storage", 0))


class StoreEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source == null or source.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.add_counters(source, "storage", 1)

	func describe() -> String:
		return "puts a storage counter on City of Shadows"
