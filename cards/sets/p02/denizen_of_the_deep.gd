extends CardScript
## Denizen of the Deep — {6}{U}{U} — Creature — Serpent — 11/11 (Portal Second Age, 1998).
## Oracle: When this creature enters, return each other creature you control to its owner's hand.

func build() -> CardData:
	var c := CardData.new("Denizen of the Deep", "{6}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(11, 11)
	c.with_subtypes(["serpent"])
	c.oracle("When this creature enters, return each other creature you control to its owner's hand.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
