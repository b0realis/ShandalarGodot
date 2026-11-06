extends CardScript
## Fleeting Image — {2}{U} — Creature — Illusion (rare, ulg).
## Oracle: Flying (This creature can't be blocked except by creatures with flying or reach.)
##         {1}{U}: Return this creature to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fleeting Image", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["illusion"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying (This creature can't be blocked except by creatures with flying or reach.)\n{1}{U}: Return this creature to its owner's hand.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
