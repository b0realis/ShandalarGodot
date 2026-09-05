extends CardScript
## Nevinyrral's Disk — {4} — Artifact (2ed, rare)
## Oracle: This artifact enters the battlefield tapped.
##         {1}, {T}: Destroy all artifacts, creatures, and enchantments.
##
## Implementation: with_enters_tapped() (so it can't fire the turn it
## lands — the card's built-in one-turn telegraph) + an activated
## DestroyAllEffect over artifacts/creatures/enchantments. The snapshot in
## DestroyAllEffect includes the Disk itself, so it dies in its own blast,
## as printed. The Witch's signature card per the dos486 enemy notes.


func build() -> CardData:
	return CardData.new("Nevinyrral's Disk", "{4}", Mtg.CardType.ARTIFACT) \
		.with_enters_tapped() \
		.activated(ActivatedAbility.new(
			"{1}", true,
			[DestroyAllEffect.new("all artifacts, creatures, and enchantments", _in_blast)],
			"{1}, {T}: Destroy all artifacts, creatures, and enchantments.")) \
		.oracle("This artifact enters the battlefield tapped.\n{1}, {T}: Destroy all artifacts, creatures, and enchantments.")


static func _in_blast(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT) \
		or inst.is_creature() \
		or inst.is_type(Mtg.CardType.ENCHANTMENT)
