extends CardScript
## Warrior's Stand — {1}{W} — Instant (Portal Second Age, 1998).
## Oracle: Cast this spell only during the declare attackers step and only if you've been attacked this step.
## Oracle: Creatures you control get +2/+2 until end of turn.

func build() -> CardData:
	var c := CardData.new("Warrior's Stand", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only during the declare attackers step and only if you've been attacked this step.\nCreatures you control get +2/+2 until end of turn.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
