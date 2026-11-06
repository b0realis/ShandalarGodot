extends CardScript
## Skittering Horror — {2}{B} — Creature — Phyrexian Horror (common, uds).
## Oracle: When you cast a creature spell, sacrifice this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Skittering Horror", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(4, 3)
	c.with_subtypes(["phyrexian","horror"])
	c.oracle("When you cast a creature spell, sacrifice this creature.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
