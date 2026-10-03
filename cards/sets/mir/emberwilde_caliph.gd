extends CardScript
## Emberwilde Caliph — {2}{U}{R} — Creature — Djinn (rare, mir).
## Oracle: Flying, trample
##         This creature attacks each combat if able.
##         Whenever this creature deals damage, you lose that much life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Emberwilde Caliph", "{2}{U}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["djinn"])
	c.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.TRAMPLE])
	c.oracle("Flying, trample\nThis creature attacks each combat if able.\nWhenever this creature deals damage, you lose that much life.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
