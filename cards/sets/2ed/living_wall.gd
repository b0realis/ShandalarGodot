extends CardScript
## Living Wall — {4} — Artifact Creature — Wall — 0/6 — (2ed, uncommon)
## Oracle: Defender (This creature can't attack.)
##         {1}: Regenerate this creature.
##
## Implementation: colorless regenerating wall — ARTIFACT|CREATURE types,
## defender, and a generic-mana regeneration ability any deck can pay.


func build() -> CardData:
	return CardData.new("Living Wall", "{4}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(0, 6) \
		.with_subtypes(["wall"]) \
		.with_keywords([Mtg.Keyword.DEFENDER]) \
		.activated(ActivatedAbility.new(
			"{1}", false,
			[RegenerateEffect.new()],
			"{1}: Regenerate this creature.")) \
		.oracle("Defender\n{1}: Regenerate this creature.")
