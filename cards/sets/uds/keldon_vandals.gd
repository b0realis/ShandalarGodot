extends CardScript
## Keldon Vandals — {2}{R} — Creature — Human Rogue (common, uds).
## Oracle: Echo {2}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         When this creature enters, destroy target artifact.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Keldon Vandals", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 1)
	c.with_subtypes(["human","rogue"])
	c.oracle("Echo {2}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\nWhen this creature enters, destroy target artifact.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
