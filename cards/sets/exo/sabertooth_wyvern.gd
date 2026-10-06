extends CardScript
## Sabertooth Wyvern — {4}{R} — Creature — Drake (uncommon, exo).
## Oracle: Flying, first strike
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sabertooth Wyvern", "{4}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.FIRST_STRIKE])
	c.oracle("Flying, first strike")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
