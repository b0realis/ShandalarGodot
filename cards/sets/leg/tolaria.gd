extends CardScript
## Tolaria — Legendary Land — (leg, uncommon)
## Oracle: {T}: Add {U}.
##         {T}: Target creature loses banding and all "bands with other"
##         abilities until end of turn. Activate only during any upkeep
##         step.
##
## Implementation: a blue mana ability plus a banding-stripping
## LoseAbilityEffect restricted to the upkeep step (during_step, with no
## turn restriction — "any upkeep", so it works on the opponent's turn
## too, which is when a banding attack is being planned).


func build() -> CardData:
	return CardData.new("Tolaria", "", Mtg.CardType.LAND) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.mana(ManaAbility.new(Mtg.ManaColor.U)) \
		.activated(ActivatedAbility.new(
			"", true,
			[LoseAbilityEffect.new([Mtg.Keyword.BANDING], "banding")],
			"{T}: Target creature loses banding and all \"bands with other\" abilities "
			+ "until end of turn. Activate only during any upkeep step.") \
			.during_step(Mtg.Step.UPKEEP)) \
		.oracle("{T}: Add {U}.\n{T}: Target creature loses banding and all \"bands "
			+ "with other\" abilities until end of turn. Activate only during any "
			+ "upkeep step.")
