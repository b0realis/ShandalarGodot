extends CardScript
## Viashino Runner — {3}{R} — Creature — Lizard (common, usg).
## Oracle: Menace (This creature can't be blocked except by two or more creatures.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Viashino Runner", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["lizard"])
	c.oracle("Menace (This creature can't be blocked except by two or more creatures.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
