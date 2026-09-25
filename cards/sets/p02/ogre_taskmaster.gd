extends CardScript
## Ogre Taskmaster — {3}{R} — Creature — Ogre — 4/3 (Portal Second Age, 1998).
## Oracle: This creature can't block.

func build() -> CardData:
	var c := CardData.new("Ogre Taskmaster", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 3)
	c.with_subtypes(["ogre"])
	c.oracle("This creature can't block.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
