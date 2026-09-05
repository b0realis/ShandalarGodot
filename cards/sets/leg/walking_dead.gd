extends CardScript
## Walking Dead — {1}{B} — Creature — Zombie — 1/1 — (leg, common)
## Oracle: {B}: Regenerate this creature.
##
## Implementation: Drudge Skeletons' ability on a 1/1 that can also attack
## for one. Each activation buys exactly one shield (CR 701.15); the test
## pins that a second destruction gets through.


func build() -> CardData:
	return CardData.new("Walking Dead", "{1}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["zombie"]) \
		.activated(ActivatedAbility.new(
			"{B}", false,
			[RegenerateEffect.new()],
			"{B}: Regenerate Walking Dead.")) \
		.oracle("{B}: Regenerate this creature.")
