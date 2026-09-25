extends CardScript
## Prowling Nightstalker — {3}{B} — Creature — Nightstalker — 2/2 (Portal Second Age, 1998).
## Oracle: This creature can't be blocked except by black creatures.

func build() -> CardData:
	var c := CardData.new("Prowling Nightstalker", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["nightstalker"])
	c.oracle("This creature can't be blocked except by black creatures.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
