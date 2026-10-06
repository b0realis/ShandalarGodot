extends CardScript
## Reckless Ogre — {3}{R} — Creature — Ogre (common, exo).
## Oracle: Whenever this creature attacks alone, it gets +3/+0 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reckless Ogre", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["ogre"])
	c.oracle("Whenever this creature attacks alone, it gets +3/+0 until end of turn.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
