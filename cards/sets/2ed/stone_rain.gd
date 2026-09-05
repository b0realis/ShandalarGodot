extends CardScript
## Stone Rain — {2}{R} — Sorcery (2ed, common)
## Oracle: Destroy target land.
##
## Implementation: DestroyEffect with a land-filtered PERMANENT spec.
## Duals are prime targets, as history demands.


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _is_land)
	return CardData.new("Stone Rain", "{2}{R}", Mtg.CardType.SORCERY) \
		.spell(DestroyEffect.new(spec)) \
		.oracle("Destroy target land.")


static func _is_land(inst: CardInstance) -> bool:
	return inst.is_land()
