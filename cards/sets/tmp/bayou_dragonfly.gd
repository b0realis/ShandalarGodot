extends CardScript
## Bayou Dragonfly — {1}{G} — Creature — Insect (common, tmp).
## Oracle: Flying; swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bayou Dragonfly", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["insect"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.with_landwalk(["swamp"])
	c.oracle("Flying; swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
