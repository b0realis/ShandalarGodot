extends CardScript
## Viashino Outrider — {2}{R} — Creature — Lizard (common, usg).
## Oracle: Echo {2}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Viashino Outrider", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 3)
	c.with_subtypes(["lizard"])
	c.oracle("Echo {2}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
