extends CardScript
## Raven Familiar — {2}{U} — Creature — Bird (uncommon, ulg).
## Oracle: Flying
##         Echo {2}{U} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         When this creature enters, look at the top three cards of your library. Put one of them into your hand and the rest on the bottom of your library in any order.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Raven Familiar", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["bird"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nEcho {2}{U} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\nWhen this creature enters, look at the top three cards of your library. Put one of them into your hand and the rest on the bottom of your library in any order.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
