extends CardScript
## Wild Griffin — {2}{W} — Creature — Griffin — 2/2 (Portal Second Age, 1998).
## Oracle: Flying

func build() -> CardData:
	var c := CardData.new("Wild Griffin", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["griffin"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying")
	return c
