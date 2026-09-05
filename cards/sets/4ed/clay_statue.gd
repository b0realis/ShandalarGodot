extends CardScript
## Clay Statue — {4} — Artifact Creature — Golem — 3/1 (4ed, common; first printed in Antiquities)
## Oracle: {2}: Regenerate this creature.
##
## Implementation: Drudge Skeletons' regeneration package on a colorless
## body with a generic cost — any deck's regenerator.


func build() -> CardData:
	return CardData.new("Clay Statue", "{4}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(3, 1) \
		.with_subtypes(["golem"]) \
		.activated(ActivatedAbility.new(
			"{2}", false,
			[RegenerateEffect.new()],
			"{2}: Regenerate this creature.")) \
		.oracle("{2}: Regenerate this creature.")
