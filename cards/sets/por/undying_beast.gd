extends CardScript
## Undying Beast — {3}{B} — Creature — Beast (Portal, 1997).
## Oracle: When this creature dies, put it on top of its owner's library.

func build() -> CardData:
	var c := CardData.new("Undying Beast", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["beast"])
	c.oracle("When this creature dies, put it on top of its owner's library.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
