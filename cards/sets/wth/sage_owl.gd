extends CardScript
## Sage Owl — {1}{U} — Creature — Bird (common, wth).
## Oracle: Flying
##         When this creature enters, look at the top four cards of your library, then put them back in any order.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sage Owl", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["bird"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, look at the top four cards of your library, then put them back in any order.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
