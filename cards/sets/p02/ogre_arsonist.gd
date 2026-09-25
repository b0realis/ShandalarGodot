extends CardScript
## Ogre Arsonist — {4}{R} — Creature — Ogre — 3/3 (Portal Second Age, 1998).
## Oracle: When this creature enters, destroy target land.

func build() -> CardData:
	var c := CardData.new("Ogre Arsonist", "{4}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["ogre"])
	c.oracle("When this creature enters, destroy target land.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
