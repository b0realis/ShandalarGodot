extends CardScript
## Treetop Defense — {1}{G} — Instant (Portal, 1997).
## Oracle: Cast this spell only during the declare attackers step and only if you've been attacked this step.
## Oracle: Creatures you control gain reach until end of turn. (They can block creatures with flying.)

func build() -> CardData:
	var c := CardData.new("Treetop Defense", "{1}{G}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only during the declare attackers step and only if you've been attacked this step.\nCreatures you control gain reach until end of turn. (They can block creatures with flying.)")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
