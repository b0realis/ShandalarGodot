extends CardScript
## Flowstone Mauler — {4}{R}{R} — Creature — Beast (rare, sth).
## Oracle: Trample
##         {R}: This creature gets +1/-1 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flowstone Mauler", "{4}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 5)
	c.with_subtypes(["beast"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample\n{R}: This creature gets +1/-1 until end of turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
