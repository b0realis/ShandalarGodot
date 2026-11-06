extends CardScript
## Phyrexian Plaguelord — {3}{B}{B} — Creature — Phyrexian Carrier (rare, ulg).
## Oracle: {T}, Sacrifice this creature: Target creature gets -4/-4 until end of turn.
##         Sacrifice a creature: Target creature gets -1/-1 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Plaguelord", "{3}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["phyrexian","carrier"])
	c.oracle("{T}, Sacrifice this creature: Target creature gets -4/-4 until end of turn.\nSacrifice a creature: Target creature gets -1/-1 until end of turn.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
