extends CardScript
## River Boa — {1}{G} — Creature — Snake (common, vis).
## Oracle: Islandwalk (This creature can't be blocked as long as defending player controls an Island.)
##         {G}: Regenerate this creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("River Boa", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["snake"])
	c.with_landwalk(["island"])
	c.oracle("Islandwalk (This creature can't be blocked as long as defending player controls an Island.)\n{G}: Regenerate this creature.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
