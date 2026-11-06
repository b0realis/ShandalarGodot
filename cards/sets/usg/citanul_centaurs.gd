extends CardScript
## Citanul Centaurs — {3}{G} — Creature — Centaur (rare, usg).
## Oracle: Shroud (This creature can't be the target of spells or abilities.)
##         Echo {3}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Citanul Centaurs", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(6, 3)
	c.with_subtypes(["centaur"])
	c.oracle("Shroud (This creature can't be the target of spells or abilities.)\nEcho {3}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
