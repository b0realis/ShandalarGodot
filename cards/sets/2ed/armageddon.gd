extends CardScript
## Armageddon — {3}{W} — Sorcery (2ed, rare)
## Oracle: Destroy all lands.
##
## Implementation: DestroyAllEffect with a land filter — symmetric, both
## players' lands, exactly as printed. (Regeneration technically applies to
## lands per the rules; no land in the pool regenerates, so the default
## can_regenerate=true is academic.)


func build() -> CardData:
	return CardData.new("Armageddon", "{3}{W}", Mtg.CardType.SORCERY) \
		.spell(DestroyAllEffect.new("all lands", _is_land)) \
		.oracle("Destroy all lands.")


static func _is_land(inst: CardInstance) -> bool:
	return inst.is_land()
