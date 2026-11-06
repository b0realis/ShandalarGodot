extends CardScript
## Squirming Mass — {1}{B} — Creature — Horror (common, uds).
## Oracle: Fear (This creature can't be blocked except by artifact creatures and/or black creatures.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Squirming Mass", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["horror"])
	c.with_keywords([Mtg.Keyword.FEAR])
	c.oracle("Fear (This creature can't be blocked except by artifact creatures and/or black creatures.)")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
