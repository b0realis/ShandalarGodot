extends CardScript
## Python — {1}{B}{B} — Creature — Snake (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Python", "{1}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["snake"])
	c.oracle("")
	return c
