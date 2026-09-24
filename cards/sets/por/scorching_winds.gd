extends CardScript
## Scorching Winds — {R} — Instant (Portal, 1997).
## Oracle: Cast this spell only during the declare attackers step and only if you've been attacked this step.
## Oracle: Scorching Winds deals 1 damage to each attacking creature.

func build() -> CardData:
	var c := CardData.new("Scorching Winds", "{R}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only during the declare attackers step and only if you've been attacked this step.\nScorching Winds deals 1 damage to each attacking creature.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
