extends CardScript
## Tsunami — {3}{G} — Sorcery (2ed, uncommon)
## Oracle: Destroy all Islands.
##
## Implementation: DestroyAllEffect filtered by land SUBTYPE — duals with
## the island type drown too, as printed. Green's color-hoser half of the
## pair with flashfires.gd.


func build() -> CardData:
	return CardData.new("Tsunami", "{3}{G}", Mtg.CardType.SORCERY) \
		.spell(DestroyAllEffect.new("all Islands", _is_island)) \
		.oracle("Destroy all Islands.")


static func _is_island(inst: CardInstance) -> bool:
	return inst.is_land() and inst.has_subtype("island")
