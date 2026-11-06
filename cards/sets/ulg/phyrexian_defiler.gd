extends CardScript
## Phyrexian Defiler — {2}{B}{B} — Creature — Phyrexian Carrier (uncommon, ulg).
## Oracle: {T}, Sacrifice this creature: Target creature gets -3/-3 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Defiler", "{2}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["phyrexian","carrier"])
	c.oracle("{T}, Sacrifice this creature: Target creature gets -3/-3 until end of turn.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
