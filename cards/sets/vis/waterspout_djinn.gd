extends CardScript
## Waterspout Djinn — {2}{U}{U} — Creature — Djinn (uncommon, vis).
## Oracle: Flying
##         At the beginning of your upkeep, sacrifice this creature unless you return an untapped Island you control to its owner's hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Waterspout Djinn", "{2}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["djinn"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nAt the beginning of your upkeep, sacrifice this creature unless you return an untapped Island you control to its owner's hand.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
