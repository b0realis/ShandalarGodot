extends CardScript
## Flowstone Wyvern — {3}{R}{R} — Creature — Drake (rare, tmp).
## Oracle: Flying
##         {R}: This creature gets +2/-2 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flowstone Wyvern", "{3}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{R}: This creature gets +2/-2 until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
