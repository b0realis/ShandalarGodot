extends CardScript
## Acridian — {1}{G} — Creature — Insect (common, usg).
## Oracle: Echo {1}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Acridian", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 4)
	c.with_subtypes(["insect"])
	c.oracle("Echo {1}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
