extends CardScript
## Spotted Griffin — {3}{W} — Creature — Griffin (Portal, 1997).
## Oracle: Flying

func build() -> CardData:
	var c := CardData.new("Spotted Griffin", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["griffin"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying")
	return c
