extends CardScript
## Goblin Masons — {1}{R} — Creature — Goblin (common, uds).
## Oracle: When this creature dies, destroy target Wall.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Masons", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["goblin"])
	c.oracle("When this creature dies, destroy target Wall.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
