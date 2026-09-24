extends CardScript
## Assassin's Blade — {1}{B} — Instant (Portal, 1997).
## Oracle: Cast this spell only during the declare attackers step and only if you've been attacked this step.
## Oracle: Destroy target nonblack attacking creature.

func build() -> CardData:
	var c := CardData.new("Assassin's Blade", "{1}{B}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only during the declare attackers step and only if you've been attacked this step.\nDestroy target nonblack attacking creature.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
