extends CardScript
## Jayemdae Tome — {4} — Artifact — Book (2ed, rare)
## Oracle: {4}, {T}: Draw a card.
##
## Implementation: mana+tap activated ability, DrawEffect(1). The honest
## grinder's card-advantage engine of the era. Subtype Book, like its
## siblings Jalum Tome (atq) and Book of Rass (drk) — nothing in the 1997
## pool cares about the subtype, but the type line is part of the card.


func build() -> CardData:
	return CardData.new("Jayemdae Tome", "{4}", Mtg.CardType.ARTIFACT) \
		.with_subtypes(["book"]) \
		.activated(ActivatedAbility.new(
			"{4}", true,
			[DrawEffect.new(1)],
			"{4}, {T}: Draw a card.")) \
		.oracle("{4}, {T}: Draw a card.")
