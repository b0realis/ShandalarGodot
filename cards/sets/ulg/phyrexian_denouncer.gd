extends CardScript
## Phyrexian Denouncer — {1}{B} — Creature — Phyrexian Carrier (common, ulg).
## Oracle: {T}, Sacrifice this creature: Target creature gets -1/-1 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Denouncer", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["phyrexian","carrier"])
	c.oracle("{T}, Sacrifice this creature: Target creature gets -1/-1 until end of turn.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
