extends CardScript
## Ice Storm — {2}{G} — Sorcery — (2ed, uncommon)
## Oracle: Destroy target land.
##
## Implementation: green's one land-kill of the era — same filtered
## DestroyEffect as Stone Rain/Sinkhole. mage-go models it with the same
## shared land-destruction constructor.


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land",
		func(inst: CardInstance) -> bool: return inst.is_land())
	return CardData.new("Ice Storm", "{2}{G}", Mtg.CardType.SORCERY) \
		.spell(DestroyEffect.new(spec)) \
		.oracle("Destroy target land.")
