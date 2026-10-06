extends CardScript
## Avenging Angel — {3}{W}{W} — Creature — Angel (rare, tmp).
## Oracle: Flying
##         When this creature dies, you may put it on top of its owner's library.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Avenging Angel", "{3}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["angel"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature dies, you may put it on top of its owner's library.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
