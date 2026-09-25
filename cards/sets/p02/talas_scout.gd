extends CardScript
## Talas Scout — {1}{U} — Creature — Human Pirate Scout — 1/2 (Portal Second Age, 1998).
## Oracle: Flying

func build() -> CardData:
	var c := CardData.new("Talas Scout", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["human","pirate","scout"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying")
	return c
