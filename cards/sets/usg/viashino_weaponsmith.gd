extends CardScript
## Viashino Weaponsmith — {3}{R} — Creature — Lizard (common, usg).
## Oracle: Whenever this creature becomes blocked by a creature, this creature gets +2/+2 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Viashino Weaponsmith", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["lizard"])
	c.oracle("Whenever this creature becomes blocked by a creature, this creature gets +2/+2 until end of turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
