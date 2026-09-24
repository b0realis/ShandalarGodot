extends CardScript
## Craven Giant — {2}{R} — Creature — Giant (Portal, 1997).
## Oracle: This creature can't block.

func build() -> CardData:
	var c := CardData.new("Craven Giant", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 1)
	c.with_subtypes(["giant"])
	c.oracle("This creature can't block.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
