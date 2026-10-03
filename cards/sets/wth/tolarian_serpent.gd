extends CardScript
## Tolarian Serpent — {5}{U}{U} — Creature — Serpent (rare, wth).
## Oracle: At the beginning of your upkeep, mill seven cards.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tolarian Serpent", "{5}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(7, 7)
	c.with_subtypes(["serpent"])
	c.oracle("At the beginning of your upkeep, mill seven cards.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
