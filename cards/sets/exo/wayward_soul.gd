extends CardScript
## Wayward Soul — {2}{U}{U} — Creature — Spirit (common, exo).
## Oracle: Flying
##         {U}: Put this creature on top of its owner's library.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wayward Soul", "{2}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{U}: Put this creature on top of its owner's library.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
