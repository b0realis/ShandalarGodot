extends CardScript
## Niall Silvain — {G}{G}{G} — Creature — Ouphe — 2/2 — (drk, rare)
## Oracle: {G}{G}{G}{G}, {T}: Regenerate target creature.
##
## Implementation: Ragnar's ability at green's price — four mana and a tap
## for one regeneration shield a turn, on any creature. Expensive, but in
## a deck with mana to burn it makes the whole board very hard to remove.


func build() -> CardData:
	return CardData.new("Niall Silvain", "{G}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["ouphe"]) \
		.activated(ActivatedAbility.new(
			"{G}{G}{G}{G}", true,
			[RegenerateEffect.new().target_creature()],
			"{G}{G}{G}{G}, {T}: Regenerate target creature.")) \
		.oracle("{G}{G}{G}{G}, {T}: Regenerate target creature.")
