extends CardScript
## Ironhoof Ox — {3}{G}{G} — Creature — Ox — 4/4 (Portal Second Age, 1998).
## Oracle: This creature can't be blocked by more than one creature.

func build() -> CardData:
	var c := CardData.new("Ironhoof Ox", "{3}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["ox"])
	c.oracle("This creature can't be blocked by more than one creature.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
