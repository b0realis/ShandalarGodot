extends CardScript
## Angus Mackenzie — {G}{W}{U} — Legendary Creature — Human Cleric — 2/2 — (leg, rare)
## Oracle: {G}{W}{U}, {T}: Prevent all combat damage that would be dealt
##         this turn. Activate only before the combat damage step.
##
## Implementation: PreventCombatDamageEffect (the Fog effect) on a
## repeatable body, with the printed timing rider expressed as
## ActivatedAbility.before_step(COMBAT_DAMAGE). One Fog a turn, forever,
## is why Angus headlined the era's most hated control decks.


func build() -> CardData:
	return CardData.new("Angus Mackenzie", "{G}{W}{U}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "cleric"]) \
		.activated(ActivatedAbility.new(
			"{G}{W}{U}", true, [PreventCombatDamageEffect.new()],
			"{G}{W}{U}, {T}: Prevent all combat damage that would be dealt this turn. "
			+ "Activate only before the combat damage step.") \
			.before_step(Mtg.Step.COMBAT_DAMAGE)) \
		.oracle("{G}{W}{U}, {T}: Prevent all combat damage that would be dealt this "
			+ "turn. Activate only before the combat damage step.")
