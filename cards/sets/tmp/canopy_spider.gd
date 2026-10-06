extends CardScript
## Canopy Spider — {1}{G} — Creature — Spider (common, tmp).
## Oracle: Reach (This creature can block creatures with flying.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Canopy Spider", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 3)
	c.with_subtypes(["spider"])
	c.with_keywords([Mtg.Keyword.REACH])
	c.oracle("Reach (This creature can block creatures with flying.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
