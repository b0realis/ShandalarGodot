extends CardScript
## Warrior's Charge — {2}{W} — Sorcery (Portal, 1997).
## Oracle: Creatures you control get +1/+1 until end of turn.

func build() -> CardData:
	var c := CardData.new("Warrior's Charge", "{2}{W}", Mtg.CardType.SORCERY)
	c.oracle("Creatures you control get +1/+1 until end of turn.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
