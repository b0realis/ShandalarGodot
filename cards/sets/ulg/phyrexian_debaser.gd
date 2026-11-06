extends CardScript
## Phyrexian Debaser — {3}{B} — Creature — Phyrexian Carrier (common, ulg).
## Oracle: Flying
##         {T}, Sacrifice this creature: Target creature gets -2/-2 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Debaser", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["phyrexian","carrier"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{T}, Sacrifice this creature: Target creature gets -2/-2 until end of turn.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
