extends CardScript
## Tivadar's Crusade — {1}{W}{W} — Sorcery — (drk, uncommon)
## Oracle: Destroy all Goblins.
##
## Implementation: DestroyAllEffect filtered on the LIVE goblin subtype —
## so a Goblin King's own tribe dies with it, and a creature merely
## granted the type would go too. The era's most pointed sideboard card,
## aimed squarely at The Dark's goblin deck.


func build() -> CardData:
	return CardData.new("Tivadar's Crusade", "{1}{W}{W}", Mtg.CardType.SORCERY) \
		.spell(DestroyAllEffect.new("all Goblins", _is_goblin)) \
		.oracle("Destroy all Goblins.")


static func _is_goblin(inst: CardInstance) -> bool:
	return inst.is_creature() and inst.has_subtype("goblin")
