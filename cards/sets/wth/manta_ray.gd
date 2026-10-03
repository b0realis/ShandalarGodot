extends CardScript
## Manta Ray — {1}{U}{U} — Creature — Fish (common, wth).
## Oracle: This creature can't attack unless defending player controls an Island.
##         This creature can't be blocked except by blue creatures.
##         When you control no Islands, sacrifice this creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Manta Ray", "{1}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["fish"])
	c.oracle("This creature can't attack unless defending player controls an Island.\nThis creature can't be blocked except by blue creatures.\nWhen you control no Islands, sacrifice this creature.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
