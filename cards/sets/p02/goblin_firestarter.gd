extends CardScript
## Goblin Firestarter — {R} — Creature — Goblin — 1/1 (Portal Second Age, 1998).
## Oracle: Sacrifice this creature: It deals 1 damage to any target. Activate only during your turn, before attackers are declared.

func build() -> CardData:
	var c := CardData.new("Goblin Firestarter", "{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["goblin"])
	c.oracle("Sacrifice this creature: It deals 1 damage to any target. Activate only during your turn, before attackers are declared.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
