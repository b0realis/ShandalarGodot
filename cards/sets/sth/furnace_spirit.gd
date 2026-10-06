extends CardScript
## Furnace Spirit — {2}{R} — Creature — Spirit (common, sth).
## Oracle: Haste
##         {R}: This creature gets +1/+0 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Furnace Spirit", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["spirit"])
	c.with_keywords([Mtg.Keyword.HASTE])
	c.oracle("Haste\n{R}: This creature gets +1/+0 until end of turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
