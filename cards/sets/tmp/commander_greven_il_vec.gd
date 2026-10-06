extends CardScript
## Commander Greven il-Vec — {3}{B}{B}{B} — Legendary Creature — Phyrexian Human Warrior (rare, tmp).
## Oracle: Fear (This creature can't be blocked except by artifact creatures and/or black creatures.)
##         When Commander Greven il-Vec enters, sacrifice a creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Commander Greven il-Vec", "{3}{B}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(7, 5)
	c.with_subtypes(["phyrexian","human","warrior"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.with_keywords([Mtg.Keyword.FEAR])
	c.oracle("Fear (This creature can't be blocked except by artifact creatures and/or black creatures.)\nWhen Commander Greven il-Vec enters, sacrifice a creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
