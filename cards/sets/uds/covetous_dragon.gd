extends CardScript
## Covetous Dragon — {4}{R} — Creature — Dragon (rare, uds).
## Oracle: Flying
##         When you control no artifacts, sacrifice this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Covetous Dragon", "{4}{R}", Mtg.CardType.CREATURE)
	c.pt(6, 5)
	c.with_subtypes(["dragon"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen you control no artifacts, sacrifice this creature.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
