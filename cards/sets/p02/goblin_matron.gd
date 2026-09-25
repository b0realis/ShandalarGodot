extends CardScript
## Goblin Matron — {2}{R} — Creature — Goblin — 1/1 (Portal Second Age, 1998).
## Oracle: When this creature enters, you may search your library for a Goblin card, reveal that card, put it into your hand, then shuffle.

func build() -> CardData:
	var c := CardData.new("Goblin Matron", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["goblin"])
	c.oracle("When this creature enters, you may search your library for a Goblin card, reveal that card, put it into your hand, then shuffle.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
