extends CardScript
## Drowned — {1}{U} — Creature — Zombie — 1/1 — (drk, common)
## Oracle: {B}: Regenerate this creature.
##
## Implementation: a blue zombie with the standard black-mana regeneration
## ability (drudge_skeletons.gd pattern) — splash bait for U/B decks.


func build() -> CardData:
	return CardData.new("Drowned", "{1}{U}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["zombie"]) \
		.activated(ActivatedAbility.new(
			"{B}", false,
			[RegenerateEffect.new()],
			"{B}: Regenerate this creature.")) \
		.oracle("{B}: Regenerate this creature.")
