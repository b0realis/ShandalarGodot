extends CardScript
## Shivan Phoenix — {4}{R}{R} — Creature — Phoenix (rare, ulg).
## Oracle: Flying
##         When this creature dies, return it to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shivan Phoenix", "{4}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["phoenix"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature dies, return it to its owner's hand.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
