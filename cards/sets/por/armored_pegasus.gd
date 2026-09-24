extends CardScript
## Armored Pegasus — {1}{W} — Creature — Pegasus (Portal, 1997).
## Oracle: Flying

func build() -> CardData:
	var c := CardData.new("Armored Pegasus", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["pegasus"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying")
	return c
