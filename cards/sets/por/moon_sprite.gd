extends CardScript
## Moon Sprite — {1}{G} — Creature — Faerie (Portal, 1997).
## Oracle: Flying

func build() -> CardData:
	var c := CardData.new("Moon Sprite", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["faerie"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying")
	return c
