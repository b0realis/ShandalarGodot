extends CardScript
## Moaning Spirit — {2}{B} — Creature — Spirit — 2/1 (Portal Second Age, 1998).
## Oracle: Flying

func build() -> CardData:
	var c := CardData.new("Moaning Spirit", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying")
	return c
