extends CardScript
## Lowland Giant — {2}{R}{R} — Creature — Giant (common, tmp).
## Oracle: (No rules text.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lowland Giant", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 3)
	c.with_subtypes(["giant"])
	c.oracle("")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
