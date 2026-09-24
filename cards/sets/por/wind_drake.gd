extends CardScript
## Wind Drake — {2}{U} — Creature — Drake (Portal, 1997).
## Oracle: Flying

func build() -> CardData:
	var c := CardData.new("Wind Drake", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying")
	return c
