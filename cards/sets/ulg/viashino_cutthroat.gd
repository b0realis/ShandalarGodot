extends CardScript
## Viashino Cutthroat — {2}{R}{R} — Creature — Lizard (uncommon, ulg).
## Oracle: Haste
##         At the beginning of the end step, return this creature to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Viashino Cutthroat", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(5, 3)
	c.with_subtypes(["lizard"])
	c.with_keywords([Mtg.Keyword.HASTE])
	c.oracle("Haste\nAt the beginning of the end step, return this creature to its owner's hand.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
