extends CardScript
## Hidden Horror — {1}{B}{B} — Creature — Horror — 4/4 (Portal Second Age, 1998).
## Oracle: When this creature enters, sacrifice it unless you discard a creature card.

func build() -> CardData:
	var c := CardData.new("Hidden Horror", "{1}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["horror"])
	c.oracle("When this creature enters, sacrifice it unless you discard a creature card.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
