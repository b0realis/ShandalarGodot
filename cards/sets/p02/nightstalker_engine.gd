extends CardScript
## Nightstalker Engine — {4}{B} — Creature — Nightstalker — */3 (Portal Second Age, 1998).
## Oracle: Nightstalker Engine's power is equal to the number of creature cards in your graveyard.

func build() -> CardData:
	var c := CardData.new("Nightstalker Engine", "{4}{B}", Mtg.CardType.CREATURE)
	c.pt(0, 3)
	c.with_subtypes(["nightstalker"])
	c.oracle("Nightstalker Engine's power is equal to the number of creature cards in your graveyard.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
