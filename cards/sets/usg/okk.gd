extends CardScript
## Okk — {1}{R} — Creature — Goblin (rare, usg).
## Oracle: This creature can't attack unless a creature with greater power also attacks.
##         This creature can't block unless a creature with greater power also blocks.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Okk", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["goblin"])
	c.oracle("This creature can't attack unless a creature with greater power also attacks.\nThis creature can't block unless a creature with greater power also blocks.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
