extends CardScript
## Dakmor Bat — {1}{B} — Creature — Bat — 1/1 (Portal Second Age, 1998).
## Oracle: Flying

func build() -> CardData:
	var c := CardData.new("Dakmor Bat", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["bat"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying")
	return c
