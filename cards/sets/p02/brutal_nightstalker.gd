extends CardScript
## Brutal Nightstalker — {3}{B}{B} — Creature — Nightstalker — 3/2 (Portal Second Age, 1998).
## Oracle: When this creature enters, you may have target opponent discard a card.

func build() -> CardData:
	var c := CardData.new("Brutal Nightstalker", "{3}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["nightstalker"])
	c.oracle("When this creature enters, you may have target opponent discard a card.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
