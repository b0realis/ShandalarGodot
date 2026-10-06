extends CardScript
## Kezzerdrix — {2}{B}{B} — Creature — Rabbit Beast (rare, tmp).
## Oracle: First strike
##         At the beginning of your upkeep, if your opponents control no creatures, this creature deals 4 damage to you.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Kezzerdrix", "{2}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["rabbit","beast"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE])
	c.oracle("First strike\nAt the beginning of your upkeep, if your opponents control no creatures, this creature deals 4 damage to you.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
