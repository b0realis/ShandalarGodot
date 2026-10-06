extends CardScript
## Rabid Rats — {1}{B} — Creature — Rat (common, sth).
## Oracle: {T}: Target blocking creature gets -1/-1 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rabid Rats", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["rat"])
	c.oracle("{T}: Target blocking creature gets -1/-1 until end of turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
