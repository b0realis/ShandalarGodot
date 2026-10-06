extends CardScript
## Benthic Behemoth — {5}{U}{U}{U} — Creature — Serpent (rare, tmp).
## Oracle: Islandwalk (This creature can't be blocked as long as defending player controls an Island.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Benthic Behemoth", "{5}{U}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(7, 6)
	c.with_subtypes(["serpent"])
	c.with_landwalk(["island"])
	c.oracle("Islandwalk (This creature can't be blocked as long as defending player controls an Island.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
