extends CardScript
## Aboroth — {4}{G}{G} — Creature — Elemental (rare, wth).
## Oracle: Cumulative upkeep—Put a -1/-1 counter on this creature. (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Aboroth", "{4}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(9, 9)
	c.with_subtypes(["elemental"])
	c.oracle("Cumulative upkeep—Put a -1/-1 counter on this creature. (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
