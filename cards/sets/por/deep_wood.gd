extends CardScript
## Deep Wood — {1}{G} — Instant (Portal, 1997).
## Oracle: Cast this spell only during the declare attackers step and only if you've been attacked this step.
## Oracle: Prevent all damage that would be dealt to you this turn by attacking creatures.

func build() -> CardData:
	var c := CardData.new("Deep Wood", "{1}{G}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only during the declare attackers step and only if you've been attacked this step.\nPrevent all damage that would be dealt to you this turn by attacking creatures.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
