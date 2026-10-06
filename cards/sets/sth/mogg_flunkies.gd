extends CardScript
## Mogg Flunkies — {1}{R} — Creature — Goblin (common, sth).
## Oracle: This creature can't attack or block alone.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mogg Flunkies", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["goblin"])
	c.oracle("This creature can't attack or block alone.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
