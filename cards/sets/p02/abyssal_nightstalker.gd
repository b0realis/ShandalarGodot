extends CardScript
## Abyssal Nightstalker — {3}{B} — Creature — Nightstalker — 2/2 (Portal Second Age, 1998).
## Oracle: Whenever this creature attacks and isn't blocked, defending player discards a card.

func build() -> CardData:
	var c := CardData.new("Abyssal Nightstalker", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["nightstalker"])
	c.oracle("Whenever this creature attacks and isn't blocked, defending player discards a card.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
