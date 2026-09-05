extends CardScript
## Sinkhole — {B}{B} — Sorcery (2ed, common)
## Oracle: Destroy target land.
##
## Implementation: black Stone Rain — same filtered DestroyEffect (see
## stone_rain.gd). Restricted-list material in the era's constructed play.


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land",
		func(inst: CardInstance) -> bool: return inst.is_land())
	return CardData.new("Sinkhole", "{B}{B}", Mtg.CardType.SORCERY) \
		.spell(DestroyEffect.new(spec)) \
		.oracle("Destroy target land.")
