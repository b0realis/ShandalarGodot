extends CardScript
## Advance Scout — {1}{W} — Creature — Human Soldier Scout (common, tmp).
## Oracle: First strike
##         {W}: Target creature gains first strike until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Advance Scout", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","soldier","scout"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE])
	c.oracle("First strike\n{W}: Target creature gains first strike until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
