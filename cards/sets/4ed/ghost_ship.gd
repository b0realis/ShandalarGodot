extends CardScript
## Ghost Ship — {2}{U}{U} — Creature — Spirit — 2/4 — (4ed, uncommon)
## Oracle: Flying
##         {U}{U}{U}: Regenerate this creature.
##
## Implementation: Drudge Skeletons' pattern with a steep blue price —
## blue's only regenerator, and a fine wall in the sky while the mana
## holds out.


func build() -> CardData:
	return CardData.new("Ghost Ship", "{2}{U}{U}", Mtg.CardType.CREATURE) \
		.pt(2, 4) \
		.with_subtypes(["spirit"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.activated(ActivatedAbility.new(
			"{U}{U}{U}", false,
			[RegenerateEffect.new()],
			"{U}{U}{U}: Regenerate this creature.")) \
		.oracle("Flying\n{U}{U}{U}: Regenerate this creature.")
