extends CardScript
## Elven Warhounds — {3}{G} — Creature — Dog (rare, tmp).
## Oracle: Whenever this creature becomes blocked by a creature, put that creature on top of its owner's library.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Elven Warhounds", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["dog"])
	c.oracle("Whenever this creature becomes blocked by a creature, put that creature on top of its owner's library.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
