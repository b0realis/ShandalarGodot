extends CardScript
## Kei Takahashi — {2}{G}{W} — Legendary Creature — Human Cleric — 2/2 —
## (leg, rare)
## Oracle: {T}: Prevent the next 2 damage that would be dealt to target
##         creature this turn.
##
## Implementation: a legendary Samite Healer, twice the dose but creatures
## only. Subject to the 1997 legend rule (the SBA buries a second copy —
## pinned in the wave-8 tests).


func build() -> CardData:
	return CardData.new("Kei Takahashi", "{2}{G}{W}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "cleric"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[PreventDamageEffect.new(2).target_creature()],
			"{T}: Prevent the next 2 damage to target creature this turn.")) \
		.oracle("{T}: Prevent the next 2 damage that would be dealt to target creature this turn.")
