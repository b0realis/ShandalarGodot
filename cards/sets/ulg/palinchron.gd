extends CardScript
## Palinchron — {5}{U}{U} — Creature — Illusion (rare, ulg).
## Oracle: Flying
##         When this creature enters, untap up to seven lands.
##         {2}{U}{U}: Return this creature to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Palinchron", "{5}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(4, 5)
	c.with_subtypes(["illusion"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, untap up to seven lands.\n{2}{U}{U}: Return this creature to its owner's hand.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
