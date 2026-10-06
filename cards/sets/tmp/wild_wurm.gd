extends CardScript
## Wild Wurm — {3}{R} — Creature — Wurm (uncommon, tmp).
## Oracle: When this creature enters, flip a coin. If you lose the flip, return this creature to its owner's hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wild Wurm", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(5, 4)
	c.with_subtypes(["wurm"])
	c.oracle("When this creature enters, flip a coin. If you lose the flip, return this creature to its owner's hand.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
