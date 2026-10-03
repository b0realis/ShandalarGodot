extends CardScript
## Benthic Djinn — {2}{U}{B} — Creature — Djinn (rare, mir).
## Oracle: Islandwalk (This creature can't be blocked as long as defending player controls an Island.)
##         At the beginning of your upkeep, you lose 2 life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Benthic Djinn", "{2}{U}{B}", Mtg.CardType.CREATURE)
	c.pt(5, 3)
	c.with_subtypes(["djinn"])
	c.with_landwalk(["island"])
	c.oracle("Islandwalk (This creature can't be blocked as long as defending player controls an Island.)\nAt the beginning of your upkeep, you lose 2 life.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
