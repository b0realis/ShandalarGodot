extends CardScript
## Fighting Drake — {2}{U}{U} — Creature — Drake (uncommon, tmp).
## Oracle: Flying
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fighting Drake", "{2}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 4)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
