extends CardScript
## Skyshroud Condor — {1}{U} — Creature — Bird (uncommon, tmp).
## Oracle: Cast this spell only if you've cast another spell this turn.
##         Flying
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Skyshroud Condor", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["bird"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Cast this spell only if you've cast another spell this turn.\nFlying")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
