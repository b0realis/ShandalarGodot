extends CardScript
## Drifting Djinn — {4}{U}{U} — Creature — Djinn (rare, usg).
## Oracle: Flying
##         At the beginning of your upkeep, sacrifice this creature unless you pay {1}{U}.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Drifting Djinn", "{4}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["djinn"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nAt the beginning of your upkeep, sacrifice this creature unless you pay {1}{U}.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
