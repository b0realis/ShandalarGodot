extends CardScript
## School of Piranha — {1}{U} — Creature — Fish (common, exo).
## Oracle: At the beginning of your upkeep, sacrifice this creature unless you pay {1}{U}.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("School of Piranha", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["fish"])
	c.oracle("At the beginning of your upkeep, sacrifice this creature unless you pay {1}{U}.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
