extends CardScript
## Norwood Riders — {3}{G} — Creature — Elf — 3/3 (Portal Second Age, 1998).
## Oracle: This creature can't be blocked by more than one creature.

func build() -> CardData:
	var c := CardData.new("Norwood Riders", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["elf"])
	c.oracle("This creature can't be blocked by more than one creature.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
