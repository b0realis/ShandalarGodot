extends CardScript
## Crater Hellion — {4}{R}{R} — Creature — Hellion Beast (rare, usg).
## Oracle: Echo {4}{R}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         When this creature enters, it deals 4 damage to each other creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Crater Hellion", "{4}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(6, 6)
	c.with_subtypes(["hellion","beast"])
	c.oracle("Echo {4}{R}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\nWhen this creature enters, it deals 4 damage to each other creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
