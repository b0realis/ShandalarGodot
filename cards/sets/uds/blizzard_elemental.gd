extends CardScript
## Blizzard Elemental — {5}{U}{U} — Creature — Elemental (rare, uds).
## Oracle: Flying
##         {3}{U}: Untap this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Blizzard Elemental", "{5}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["elemental"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{3}{U}: Untap this creature.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
