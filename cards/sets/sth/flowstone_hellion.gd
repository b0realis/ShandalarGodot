extends CardScript
## Flowstone Hellion — {4}{R} — Creature — Hellion Beast (uncommon, sth).
## Oracle: Haste
##         {0}: This creature gets +1/-1 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flowstone Hellion", "{4}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["hellion","beast"])
	c.with_keywords([Mtg.Keyword.HASTE])
	c.oracle("Haste\n{0}: This creature gets +1/-1 until end of turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
