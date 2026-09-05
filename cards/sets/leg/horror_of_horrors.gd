extends CardScript
## Horror of Horrors — {3}{B}{B} — Enchantment — (leg, uncommon)
## Oracle: Sacrifice a Swamp: Regenerate target black creature.
##
## Implementation: a free (no mana, no tap) ability whose only cost is
## "Sacrifice a Swamp", regenerating any black creature. In a mono-black
## deck with lands to spare it makes the whole board effectively
## indestructible for a turn.


func build() -> CardData:
	return CardData.new("Horror of Horrors", "{3}{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new(
			"", false,
			[RegenerateEffect.new().target_creature("target black creature", _is_black)],
			"Sacrifice a Swamp: Regenerate target black creature.") \
			.with_sacrifice_of("Swamp", _is_swamp)) \
		.oracle("Sacrifice a Swamp: Regenerate target black creature.")


static func _is_swamp(inst: CardInstance) -> bool:
	return inst.is_land() and inst.has_subtype("swamp")


static func _is_black(inst: CardInstance) -> bool:
	return (inst.cur_colors & Mtg.ManaColor.B) != 0
