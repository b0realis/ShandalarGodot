extends CardScript
## Reclusive Wight — {3}{B} — Creature — Zombie Minion (uncommon, usg).
## Oracle: At the beginning of your upkeep, if you control another nonland permanent, sacrifice this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reclusive Wight", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["zombie","minion"])
	c.oracle("At the beginning of your upkeep, if you control another nonland permanent, sacrifice this creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
