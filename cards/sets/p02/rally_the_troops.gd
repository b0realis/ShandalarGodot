extends CardScript
## Rally the Troops — {W} — Instant (Portal Second Age, 1998).
## Oracle: Cast this spell only during the declare attackers step and only if you've been attacked this step.
## Oracle: Untap all creatures you control.

func build() -> CardData:
	var c := CardData.new("Rally the Troops", "{W}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only during the declare attackers step and only if you've been attacked this step.\nUntap all creatures you control.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
