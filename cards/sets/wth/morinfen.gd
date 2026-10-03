extends CardScript
## Morinfen — {3}{B}{B} — Legendary Creature — Phyrexian Horror (rare, wth).
## Oracle: Flying
##         Cumulative upkeep—Pay 1 life. (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Morinfen", "{3}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(5, 4)
	c.with_subtypes(["phyrexian","horror"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nCumulative upkeep—Pay 1 life. (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
