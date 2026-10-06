extends CardScript
## Rootbreaker Wurm — {5}{G}{G} — Creature — Wurm (common, tmp).
## Oracle: Trample (This creature can deal excess combat damage to the player or planeswalker it's attacking.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rootbreaker Wurm", "{5}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(6, 6)
	c.with_subtypes(["wurm"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample (This creature can deal excess combat damage to the player or planeswalker it's attacking.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
