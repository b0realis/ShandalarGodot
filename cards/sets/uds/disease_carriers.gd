extends CardScript
## Disease Carriers — {2}{B}{B} — Creature — Rat (common, uds).
## Oracle: When this creature dies, target creature gets -2/-2 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Disease Carriers", "{2}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["rat"])
	c.oracle("When this creature dies, target creature gets -2/-2 until end of turn.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
