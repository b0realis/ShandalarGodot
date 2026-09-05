extends CardScript
## Flashfires — {3}{R} — Sorcery (2ed, uncommon)
## Oracle: Destroy all Plains.
##
## Implementation: tsunami.gd's red twin — all plains-typed lands burn,
## duals included.


func build() -> CardData:
	return CardData.new("Flashfires", "{3}{R}", Mtg.CardType.SORCERY) \
		.spell(DestroyAllEffect.new("all Plains", _is_plains)) \
		.oracle("Destroy all Plains.")


static func _is_plains(inst: CardInstance) -> bool:
	return inst.is_land() and inst.has_subtype("plains")
