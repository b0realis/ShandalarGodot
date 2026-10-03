extends CardScript
## Fledgling Djinn — {1}{B} — Creature — Djinn (common, wth).
## Oracle: Flying
##         At the beginning of your upkeep, this creature deals 1 damage to you.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fledgling Djinn", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["djinn"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nAt the beginning of your upkeep, this creature deals 1 damage to you.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
