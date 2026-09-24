extends CardScript
## Hulking Cyclops — {3}{R}{R} — Creature — Cyclops (Portal, 1997).
## Oracle: This creature can't block.

func build() -> CardData:
	var c := CardData.new("Hulking Cyclops", "{3}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["cyclops"])
	c.oracle("This creature can't block.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
