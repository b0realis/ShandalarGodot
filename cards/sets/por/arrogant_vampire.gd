extends CardScript
## Arrogant Vampire — {3}{B}{B} — Creature — Vampire (Portal, 1997).
## Oracle: Flying

func build() -> CardData:
	var c := CardData.new("Arrogant Vampire", "{3}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(4, 3)
	c.with_subtypes(["vampire"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying")
	return c
