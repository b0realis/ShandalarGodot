extends CardScript
## Wind Dancer — {1}{U} — Creature — Faerie (uncommon, tmp).
## Oracle: Flying
##         {T}: Target creature gains flying until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wind Dancer", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["faerie"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{T}: Target creature gains flying until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
