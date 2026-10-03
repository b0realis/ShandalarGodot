extends CardScript
## Bogardan Firefiend — {2}{R} — Creature — Elemental Spirit (common, wth).
## Oracle: When this creature dies, it deals 2 damage to target creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bogardan Firefiend", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["elemental","spirit"])
	c.oracle("When this creature dies, it deals 2 damage to target creature.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
