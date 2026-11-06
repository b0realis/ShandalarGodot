extends CardScript
## Kingfisher — {3}{U} — Creature — Bird (common, uds).
## Oracle: Flying
##         When this creature dies, draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Kingfisher", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["bird"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature dies, draw a card.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
