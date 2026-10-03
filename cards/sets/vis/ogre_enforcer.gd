extends CardScript
## Ogre Enforcer — {3}{R}{R} — Creature — Ogre (rare, vis).
## Oracle: This creature can't be destroyed by lethal damage unless lethal damage dealt by a single source is marked on it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ogre Enforcer", "{3}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["ogre"])
	c.oracle("This creature can't be destroyed by lethal damage unless lethal damage dealt by a single source is marked on it.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
