extends CardScript
## Scoria Wurm — {4}{R} — Creature — Wurm (rare, usg).
## Oracle: At the beginning of your upkeep, flip a coin. If you lose the flip, return this creature to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scoria Wurm", "{4}{R}", Mtg.CardType.CREATURE)
	c.pt(7, 7)
	c.with_subtypes(["wurm"])
	c.oracle("At the beginning of your upkeep, flip a coin. If you lose the flip, return this creature to its owner's hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
