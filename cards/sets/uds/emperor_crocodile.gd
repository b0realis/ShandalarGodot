extends CardScript
## Emperor Crocodile — {3}{G} — Creature — Crocodile (rare, uds).
## Oracle: When you control no other creatures, sacrifice this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Emperor Crocodile", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["crocodile"])
	c.oracle("When you control no other creatures, sacrifice this creature.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
