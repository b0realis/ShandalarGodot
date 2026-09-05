extends CardScript
## Lady Evangela — {W}{U}{B} — Legendary Creature — Human Cleric — 1/2 — (leg, rare)
## Oracle: {W}{B}, {T}: Prevent all combat damage that would be dealt by
##         target creature this turn.
##
## Implementation: PreventCombatDamageEffect.by_target_creature() — a
## floating until-end-of-turn shield that MtgGame.deal_damage honours for
## COMBAT damage only, so the silenced creature can still ping with an
## activated ability. Blanks the biggest attacker every turn.


func build() -> CardData:
	return CardData.new("Lady Evangela", "{W}{U}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 2) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "cleric"]) \
		.activated(ActivatedAbility.new(
			"{W}{B}", true,
			[PreventCombatDamageEffect.new().by_target_creature()],
			"{W}{B}, {T}: Prevent all combat damage that would be dealt by target "
			+ "creature this turn.")) \
		.oracle("{W}{B}, {T}: Prevent all combat damage that would be dealt by target "
			+ "creature this turn.")
