extends CardScript
## Jackalope Herd — {3}{G} — Creature — Rabbit Beast (common, exo).
## Oracle: When you cast a spell, return this creature to its owner's hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Jackalope Herd", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 5)
	c.with_subtypes(["rabbit","beast"])
	c.oracle("When you cast a spell, return this creature to its owner's hand.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
