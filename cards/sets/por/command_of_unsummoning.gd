extends CardScript
## Command of Unsummoning — {2}{U} — Instant (Portal, 1997).
## Oracle: Cast this spell only during the declare attackers step and only if you've been attacked this step.
## Oracle: Return one or two target attacking creatures to their owner's hand.

func build() -> CardData:
	var c := CardData.new("Command of Unsummoning", "{2}{U}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only during the declare attackers step and only if you've been attacked this step.\nReturn one or two target attacking creatures to their owner's hand.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
