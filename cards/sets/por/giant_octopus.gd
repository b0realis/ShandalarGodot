extends CardScript
## Giant Octopus — {3}{U} — Creature — Octopus (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Giant Octopus", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["octopus"])
	c.oracle("")
	return c
