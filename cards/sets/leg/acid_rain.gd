extends CardScript
## Acid Rain — {3}{U} — Sorcery — (leg, rare)
## Oracle: Destroy all Forests.
##
## Implementation: DestroyAllEffect with a land filter. "Forests" means
## the LAND SUBTYPE, not the card name, so anything with the subtype goes
## (Savannah, Tropical Island…) — and your own Forests drown with theirs.
## Reads the LIVE subtypes so an animated land is judged as it is now.


func build() -> CardData:
	return CardData.new("Acid Rain", "{3}{U}", Mtg.CardType.SORCERY) \
		.spell(DestroyAllEffect.new("all Forests", _is_forest)) \
		.oracle("Destroy all Forests.")


static func _is_forest(inst: CardInstance) -> bool:
	return inst.is_land() and inst.has_subtype("forest")
