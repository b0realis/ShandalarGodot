extends CardScript
## Strip Mine — Land (4ed, uncommon; first printed in Antiquities)
## Oracle: {T}: Add {C}.
##         {T}, Sacrifice this land: Destroy target land.
##
## Implementation: the reference SACRIFICE-COST card — a normal colorless
## mana ability plus an activated ability whose cost taps AND sacrifices
## the source (paid before resolution: the Mine is already in the
## graveyard while its destruction resolves, CR 601.2h). The era's most
## feared land, restricted for good reason.


func build() -> CardData:
	var land_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land",
		func(inst: CardInstance) -> bool: return inst.is_land())
	return CardData.new("Strip Mine", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.C)) \
		.activated(ActivatedAbility.new(
			"", true,
			[DestroyEffect.new(land_spec)],
			"{T}, Sacrifice this land: Destroy target land.").with_sacrifice_cost()) \
		.oracle("{T}: Add {C}.\n{T}, Sacrifice this land: Destroy target land.")
