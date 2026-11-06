extends CardScript
## Winding Wurm — {4}{G} — Creature — Wurm (common, usg).
## Oracle: Echo {4}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Winding Wurm", "{4}{G}", Mtg.CardType.CREATURE)
	c.pt(6, 6)
	c.with_subtypes(["wurm"])
	c.oracle("Echo {4}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
