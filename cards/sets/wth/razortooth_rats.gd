extends CardScript
## Razortooth Rats — {2}{B} — Creature — Rat (common, wth).
## Oracle: Fear (This creature can't be blocked except by artifact creatures and/or black creatures.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Razortooth Rats", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["rat"])
	c.with_keywords([Mtg.Keyword.FEAR])
	c.oracle("Fear (This creature can't be blocked except by artifact creatures and/or black creatures.)")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
