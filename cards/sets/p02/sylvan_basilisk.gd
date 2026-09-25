extends CardScript
## Sylvan Basilisk — {3}{G}{G} — Creature — Basilisk — 2/4 (Portal Second Age, 1998).
## Oracle: Whenever this creature becomes blocked by a creature, destroy that creature.

func build() -> CardData:
	var c := CardData.new("Sylvan Basilisk", "{3}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 4)
	c.with_subtypes(["basilisk"])
	c.oracle("Whenever this creature becomes blocked by a creature, destroy that creature.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
