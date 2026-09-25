extends CardScript
## Ogre Warrior — {3}{R} — Creature — Ogre Warrior — 3/3 (Portal Second Age, 1998).
## Oracle: (no rules text — vanilla creature)

func build() -> CardData:
	var c := CardData.new("Ogre Warrior", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["ogre","warrior"])
	c.oracle("")
	return c
