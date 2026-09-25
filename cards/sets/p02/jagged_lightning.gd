extends CardScript
## Jagged Lightning — {3}{R}{R} — Sorcery (Portal Second Age, 1998).
## Oracle: Jagged Lightning deals 3 damage to each of two target creatures.

func build() -> CardData:
	var c := CardData.new("Jagged Lightning", "{3}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Jagged Lightning deals 3 damage to each of two target creatures.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
