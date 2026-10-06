extends CardScript
## Duct Crawler — {R} — Creature — Insect (common, sth).
## Oracle: {1}{R}: Target creature can't block this creature this turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Duct Crawler", "{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["insect"])
	c.oracle("{1}{R}: Target creature can't block this creature this turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
