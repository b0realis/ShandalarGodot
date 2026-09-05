extends CardScript
## Uthden Troll — {2}{R} — Creature — Troll — 2/2 — (2ed, uncommon)
## Oracle: {R}: Regenerate this creature.
##
## Implementation: Drudge Skeletons' pattern in red — a mana-only activated
## ability building a regeneration shield on itself. Red's rare recursive
## body of the era; trades with everything and comes back for {R}.


func build() -> CardData:
	return CardData.new("Uthden Troll", "{2}{R}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["troll"]) \
		.activated(ActivatedAbility.new(
			"{R}", false,
			[RegenerateEffect.new()],
			"{R}: Regenerate this creature.")) \
		.oracle("{R}: Regenerate this creature.")
