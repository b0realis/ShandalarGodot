extends CardScript
## Cruel Edict — {1}{B} — Sorcery (Portal Second Age, 1998).
## Oracle: Target opponent sacrifices a creature of their choice.

func build() -> CardData:
	var c := CardData.new("Cruel Edict", "{1}{B}", Mtg.CardType.SORCERY)
	c.oracle("Target opponent sacrifices a creature of their choice.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
