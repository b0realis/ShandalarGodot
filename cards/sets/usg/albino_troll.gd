extends CardScript
## Albino Troll — {1}{G} — Creature — Troll (uncommon, usg).
## Oracle: Echo {1}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         {1}{G}: Regenerate this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Albino Troll", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["troll"])
	c.oracle("Echo {1}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\n{1}{G}: Regenerate this creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
