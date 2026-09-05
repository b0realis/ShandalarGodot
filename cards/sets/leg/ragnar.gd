extends CardScript
## Ragnar — {G}{W}{U} — Legendary Creature — Human Cleric — 2/2 — (leg, rare)
## Oracle: {G}{W}{U}, {T}: Regenerate target creature.
##
## Implementation: Death Ward's targeted RegenerateEffect on a repeatable
## (once per untap) body. The shield replaces the next destruction this
## turn with tap + clear damage + remove from combat (CR 701.15).


func build() -> CardData:
	return CardData.new("Ragnar", "{G}{W}{U}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "cleric"]) \
		.activated(ActivatedAbility.new(
			"{G}{W}{U}", true,
			[RegenerateEffect.new().target_creature()],
			"{G}{W}{U}, {T}: Regenerate target creature.")) \
		.oracle("{G}{W}{U}, {T}: Regenerate target creature.")
