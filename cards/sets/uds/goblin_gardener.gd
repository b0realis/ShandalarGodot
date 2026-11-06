extends CardScript
## Goblin Gardener — {3}{R} — Creature — Goblin (common, uds).
## Oracle: When this creature dies, destroy target land.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Gardener", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["goblin"])
	c.oracle("When this creature dies, destroy target land.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
