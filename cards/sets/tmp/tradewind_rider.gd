extends CardScript
## Tradewind Rider — {3}{U} — Creature — Spirit (rare, tmp).
## Oracle: Flying
##         {T}, Tap two untapped creatures you control: Return target permanent to its owner's hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tradewind Rider", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 4)
	c.with_subtypes(["spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{T}, Tap two untapped creatures you control: Return target permanent to its owner's hand.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
