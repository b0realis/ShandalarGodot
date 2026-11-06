extends CardScript
## Plated Spider — {4}{G} — Creature — Spider (common, uds).
## Oracle: Reach (This creature can block creatures with flying.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Plated Spider", "{4}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["spider"])
	c.with_keywords([Mtg.Keyword.REACH])
	c.oracle("Reach (This creature can block creatures with flying.)")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
