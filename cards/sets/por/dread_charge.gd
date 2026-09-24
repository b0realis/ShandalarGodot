extends CardScript
## Dread Charge — {3}{B} — Sorcery (Portal, 1997).
## Oracle: Black creatures you control can't be blocked this turn except by black creatures.

func build() -> CardData:
	var c := CardData.new("Dread Charge", "{3}{B}", Mtg.CardType.SORCERY)
	c.oracle("Black creatures you control can't be blocked this turn except by black creatures.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
