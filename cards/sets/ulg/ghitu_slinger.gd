extends CardScript
## Ghitu Slinger — {2}{R} — Creature — Human Nomad (common, ulg).
## Oracle: Echo {2}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         When this creature enters, it deals 2 damage to any target.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ghitu Slinger", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","nomad"])
	c.oracle("Echo {2}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\nWhen this creature enters, it deals 2 damage to any target.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
