extends CardScript
## Spindrift Drake — {U} — Creature — Drake (common, sth).
## Oracle: Flying
##         At the beginning of your upkeep, sacrifice this creature unless you pay {U}.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spindrift Drake", "{U}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nAt the beginning of your upkeep, sacrifice this creature unless you pay {U}.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
