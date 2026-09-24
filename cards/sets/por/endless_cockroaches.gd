extends CardScript
## Endless Cockroaches — {1}{B}{B} — Creature — Insect (Portal, 1997).
## Oracle: When this creature dies, return it to its owner's hand.

func build() -> CardData:
	var c := CardData.new("Endless Cockroaches", "{1}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["insect"])
	c.oracle("When this creature dies, return it to its owner's hand.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
