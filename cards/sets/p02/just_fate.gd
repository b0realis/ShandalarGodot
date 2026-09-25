extends CardScript
## Just Fate — {2}{W} — Instant (Portal Second Age, 1998).
## Oracle: Cast this spell only during the declare attackers step and only if you've been attacked this step.
## Oracle: Destroy target attacking creature.

func build() -> CardData:
	var c := CardData.new("Just Fate", "{2}{W}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only during the declare attackers step and only if you've been attacked this step.\nDestroy target attacking creature.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
