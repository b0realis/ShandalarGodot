extends CardScript
## Charging Rhino — {3}{G}{G} — Creature — Rhino (Portal, 1997).
## Oracle: This creature can't be blocked by more than one creature.

func build() -> CardData:
	var c := CardData.new("Charging Rhino", "{3}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["rhino"])
	c.oracle("This creature can't be blocked by more than one creature.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
