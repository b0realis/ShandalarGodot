extends CardScript
## Diabolic Machine — {7} — Artifact Creature — Construct — 4/4 — (4ed, uncommon)
## Oracle: {3}: Regenerate this creature.
##
## Implementation: a plain RegenerateEffect on a colourless body — seven
## mana for a 4/4 that is very hard to kill with damage, and the reason
## artifact decks of the era wanted "can't be regenerated" removal.


func build() -> CardData:
	return CardData.new("Diabolic Machine", "{7}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(4, 4) \
		.with_subtypes(["construct"]) \
		.activated(ActivatedAbility.new(
			"{3}", false, [RegenerateEffect.new()],
			"{3}: Regenerate Diabolic Machine.")) \
		.oracle("{3}: Regenerate this creature.")
