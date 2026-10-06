extends CardScript
## Minion of the Wastes — {3}{B}{B}{B} — Creature — Minion (rare, tmp).
## Oracle: Trample
##         As this creature enters, pay any amount of life.
##         Minion of the Wastes's power and toughness are each equal to the life paid as it entered.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Minion of the Wastes", "{3}{B}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["minion"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample\nAs this creature enters, pay any amount of life.\nMinion of the Wastes's power and toughness are each equal to the life paid as it entered.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
