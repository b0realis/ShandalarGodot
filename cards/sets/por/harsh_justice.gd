extends CardScript
## Harsh Justice — {2}{W} — Instant (Portal, 1997).
## Oracle: Cast this spell only during the declare attackers step and only if you've been attacked this step.
## Oracle: This turn, whenever an attacking creature deals combat damage to you, it deals that much damage to its controller.

func build() -> CardData:
	var c := CardData.new("Harsh Justice", "{2}{W}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only during the declare attackers step and only if you've been attacked this step.\nThis turn, whenever an attacking creature deals combat damage to you, it deals that much damage to its controller.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
