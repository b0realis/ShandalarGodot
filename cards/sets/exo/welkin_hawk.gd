extends CardScript
## Welkin Hawk — {1}{W} — Creature — Bird (common, exo).
## Oracle: Flying
##         When this creature dies, you may search your library for a card named Welkin Hawk, reveal that card, put it into your hand, then shuffle.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Welkin Hawk", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["bird"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature dies, you may search your library for a card named Welkin Hawk, reveal that card, put it into your hand, then shuffle.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
