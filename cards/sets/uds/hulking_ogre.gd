extends CardScript
## Hulking Ogre — {2}{R} — Creature — Ogre (common, uds).
## Oracle: This creature can't block.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hulking Ogre", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["ogre"])
	c.oracle("This creature can't block.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
