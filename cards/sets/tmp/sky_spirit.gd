extends CardScript
## Sky Spirit — {1}{W}{U} — Creature — Spirit (uncommon, tmp).
## Oracle: Flying, first strike
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sky Spirit", "{1}{W}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["spirit"])
	c.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.FIRST_STRIKE])
	c.oracle("Flying, first strike")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
