extends CardScript
## Viashino Sandswimmer — {2}{R}{R} — Creature — Lizard (rare, usg).
## Oracle: {R}: Flip a coin. If you win the flip, return this creature to its owner's hand. If you lose the flip, sacrifice this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Viashino Sandswimmer", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["lizard"])
	c.oracle("{R}: Flip a coin. If you win the flip, return this creature to its owner's hand. If you lose the flip, sacrifice this creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
