extends CardScript
## Sawtooth Ogre — {2}{R}{R} — Creature — Ogre (common, wth).
## Oracle: Whenever this creature blocks or becomes blocked by a creature, this creature deals 1 damage to that creature at end of combat.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sawtooth Ogre", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["ogre"])
	c.oracle("Whenever this creature blocks or becomes blocked by a creature, this creature deals 1 damage to that creature at end of combat.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
