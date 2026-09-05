extends CardScript
## Pendelhaven — Legendary Land — (leg, uncommon)
## Oracle: {T}: Add {G}.
##         {T}: Target 1/1 creature gets +1/+2 until end of turn.
##
## Implementation: a mana ability plus a tap-only PumpEffect whose filter
## reads LIVE power/toughness — so a creature pumped out of 1/1 stops
## being a legal target, and a shrunk 2/2 becomes one. The two abilities
## share the single untap, so each turn Pendelhaven is mana or a trick.


func build() -> CardData:
	var pump := PumpEffect.new(1, 2)
	pump.target_spec = TargetSpec.creature("target 1/1 creature", _is_one_one)
	return CardData.new("Pendelhaven", "", Mtg.CardType.LAND) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.mana(ManaAbility.new(Mtg.ManaColor.G)) \
		.activated(ActivatedAbility.new(
			"", true, [pump],
			"{T}: Target 1/1 creature gets +1/+2 until end of turn.")) \
		.oracle("{T}: Add {G}.\n{T}: Target 1/1 creature gets +1/+2 until end of turn.")


static func _is_one_one(inst: CardInstance) -> bool:
	return inst.cur_power == 1 and inst.cur_toughness == 1
