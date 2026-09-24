extends CardScript
## Starlit Angel — {3}{W}{W} — Creature — Angel (Portal, 1997).
## Oracle: Flying

func build() -> CardData:
	var c := CardData.new("Starlit Angel", "{3}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["angel"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying")
	return c
