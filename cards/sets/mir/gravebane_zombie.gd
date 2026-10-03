extends CardScript
## Gravebane Zombie — {3}{B} — Creature — Zombie (common, mir).
## Oracle: If this creature would die, put it on top of its owner's library instead.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Gravebane Zombie", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["zombie"])
	c.oracle("If this creature would die, put it on top of its owner's library instead.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
