extends CardScript
## Cinder Giant — {3}{R} — Creature — Giant (uncommon, wth).
## Oracle: At the beginning of your upkeep, this creature deals 2 damage to each other creature you control.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cinder Giant", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(5, 3)
	c.with_subtypes(["giant"])
	c.oracle("At the beginning of your upkeep, this creature deals 2 damage to each other creature you control.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
