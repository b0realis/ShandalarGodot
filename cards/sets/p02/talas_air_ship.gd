extends CardScript
## Talas Air Ship — {3}{U} — Creature — Human Pirate — 3/2 (Portal Second Age, 1998).
## Oracle: Flying

func build() -> CardData:
	var c := CardData.new("Talas Air Ship", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["human","pirate"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying")
	return c
