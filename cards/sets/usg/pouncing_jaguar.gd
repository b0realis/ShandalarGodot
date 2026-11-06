extends CardScript
## Pouncing Jaguar — {G} — Creature — Cat (common, usg).
## Oracle: Echo {G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pouncing Jaguar", "{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["cat"])
	c.oracle("Echo {G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
