extends CardScript
## Remove — {U} — Instant (Portal Second Age, 1998).
## Oracle: Cast this spell only during the declare attackers step and only if you've been attacked this step.
## Oracle: Return target attacking creature to its owner's hand.

func build() -> CardData:
	var c := CardData.new("Remove", "{U}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only during the declare attackers step and only if you've been attacked this step.\nReturn target attacking creature to its owner's hand.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
