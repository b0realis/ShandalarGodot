extends CardScript
## Horn of Deafening — {4} — Artifact — (leg, rare)
## Oracle: {2}, {T}: Prevent all combat damage that would be dealt by
##         target creature this turn.
##
## Implementation: Lady Evangela's effect on a colourless artifact — any
## deck can play it, and it silences one attacker or blocker a turn for
## two mana.


func build() -> CardData:
	return CardData.new("Horn of Deafening", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{2}", true,
			[PreventCombatDamageEffect.new().by_target_creature()],
			"{2}, {T}: Prevent all combat damage that would be dealt by target "
			+ "creature this turn.")) \
		.oracle("{2}, {T}: Prevent all combat damage that would be dealt by target "
			+ "creature this turn.")
