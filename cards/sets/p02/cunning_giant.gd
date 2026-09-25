extends CardScript
## Cunning Giant — {5}{R} — Creature — Giant — 4/4 (Portal Second Age, 1998).
## Oracle: If this creature is unblocked, you may have it assign its combat damage to a creature defending player controls.

func build() -> CardData:
	var c := CardData.new("Cunning Giant", "{5}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["giant"])
	c.oracle("If this creature is unblocked, you may have it assign its combat damage to a creature defending player controls.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
