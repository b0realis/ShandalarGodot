extends CardScript
## Ogre Berserker — {4}{R} — Creature — Ogre Berserker — 4/2 (Portal Second Age, 1998).
## Oracle: Haste

func build() -> CardData:
	var c := CardData.new("Ogre Berserker", "{4}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 2)
	c.with_subtypes(["ogre","berserker"])
	c.with_keywords([Mtg.Keyword.HASTE])
	c.oracle("Haste")
	return c
