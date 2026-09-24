extends CardScript
## Valorous Charge — {1}{W}{W} — Sorcery (Portal, 1997).
## Oracle: White creatures get +2/+0 until end of turn.

func build() -> CardData:
	var c := CardData.new("Valorous Charge", "{1}{W}{W}", Mtg.CardType.SORCERY)
	c.oracle("White creatures get +2/+0 until end of turn.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
