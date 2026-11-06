extends CardScript
## Radiant's Dragoons — {3}{W} — Creature — Human Soldier (uncommon, ulg).
## Oracle: Echo {3}{W} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         When this creature enters, you gain 5 life.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Radiant's Dragoons", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 5)
	c.with_subtypes(["human","soldier"])
	c.oracle("Echo {3}{W} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\nWhen this creature enters, you gain 5 life.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
