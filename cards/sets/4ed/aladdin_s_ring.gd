extends CardScript
## Aladdin's Ring — {8} — Artifact — (4ed, rare)
## Oracle: {8}, {T}: This artifact deals 4 damage to any target.
##
## Implementation: an ActivatedAbility with a big mana price and a
## DamageEffect payload — a colorless, repeatable Bolt-and-a-bit for
## decks with nothing better to do with eight mana. A MicroProse-era
## favorite of the AI's artifact decks.


func build() -> CardData:
	return CardData.new("Aladdin's Ring", "{8}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{8}", true,
			[DamageEffect.new(4).any_target()],
			"{8}, {T}: This artifact deals 4 damage to any target.")) \
		.oracle("{8}, {T}: This artifact deals 4 damage to any target.")
