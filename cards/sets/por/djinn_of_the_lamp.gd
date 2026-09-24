extends CardScript
## Djinn of the Lamp — {5}{U}{U} — Creature — Djinn (Portal, 1997).
## Oracle: Flying

func build() -> CardData:
	var c := CardData.new("Djinn of the Lamp", "{5}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(5, 6)
	c.with_subtypes(["djinn"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying")
	return c
