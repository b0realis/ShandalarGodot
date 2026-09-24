extends CardScript
## Fire Snake — {4}{R} — Creature — Snake (Portal, 1997).
## Oracle: When this creature dies, destroy target land.

func build() -> CardData:
	var c := CardData.new("Fire Snake", "{4}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 1)
	c.with_subtypes(["snake"])
	c.oracle("When this creature dies, destroy target land.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
