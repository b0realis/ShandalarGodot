extends CardScript
## Nekrataal — {2}{B}{B} — Creature — Human Assassin (uncommon, vis).
## Oracle: First strike
##         When this creature enters, destroy target nonartifact, nonblack creature. That creature can't be regenerated.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Nekrataal", "{2}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["human","assassin"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE])
	c.oracle("First strike\nWhen this creature enters, destroy target nonartifact, nonblack creature. That creature can't be regenerated.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
