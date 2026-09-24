extends CardScript
## Defiant Stand — {1}{W} — Instant (Portal, 1997).
## Oracle: Cast this spell only during the declare attackers step and only if you've been attacked this step.
## Oracle: Target creature gets +1/+3 until end of turn. Untap that creature.

func build() -> CardData:
	var c := CardData.new("Defiant Stand", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only during the declare attackers step and only if you've been attacked this step.\nTarget creature gets +1/+3 until end of turn. Untap that creature.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
