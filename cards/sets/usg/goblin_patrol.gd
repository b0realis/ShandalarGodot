extends CardScript
## Goblin Patrol — {R} — Creature — Goblin (common, usg).
## Oracle: Echo {R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Patrol", "{R}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["goblin"])
	c.oracle("Echo {R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
