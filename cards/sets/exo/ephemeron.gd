extends CardScript
## Ephemeron — {4}{U}{U} — Creature — Illusion (rare, exo).
## Oracle: Flying
##         Discard a card: Return this creature to its owner's hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ephemeron", "{4}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["illusion"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nDiscard a card: Return this creature to its owner's hand.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
