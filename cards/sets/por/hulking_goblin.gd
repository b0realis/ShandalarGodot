extends CardScript
## Hulking Goblin — {1}{R} — Creature — Goblin (Portal, 1997).
## Oracle: This creature can't block.

func build() -> CardData:
	var c := CardData.new("Hulking Goblin", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["goblin"])
	c.oracle("This creature can't block.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
