extends CardScript
## Yavimaya Wurm — {4}{G}{G} — Creature — Wurm (common, ulg).
## Oracle: Trample (This creature can deal excess combat damage to the player or planeswalker it's attacking.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Yavimaya Wurm", "{4}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(6, 4)
	c.with_subtypes(["wurm"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample (This creature can deal excess combat damage to the player or planeswalker it's attacking.)")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
