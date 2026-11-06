extends CardScript
## Imaginary Pet — {1}{U} — Creature — Illusion (rare, usg).
## Oracle: At the beginning of your upkeep, if you have a card in hand, return this creature to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Imaginary Pet", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["illusion"])
	c.oracle("At the beginning of your upkeep, if you have a card in hand, return this creature to its owner's hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
