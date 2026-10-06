extends CardScript
## Ogre Shaman — {3}{R}{R} — Creature — Ogre Shaman (rare, exo).
## Oracle: {2}, Discard a card at random: This creature deals 2 damage to any target.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ogre Shaman", "{3}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["ogre","shaman"])
	c.oracle("{2}, Discard a card at random: This creature deals 2 damage to any target.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
