extends CardScript
## Desert Drake — {3}{R} — Creature — Drake (Portal, 1997).
## Oracle: Flying

func build() -> CardData:
	var c := CardData.new("Desert Drake", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying")
	return c
