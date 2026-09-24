extends CardScript
## Steadfastness — {1}{W} — Sorcery (Portal, 1997).
## Oracle: Creatures you control get +0/+3 until end of turn.

func build() -> CardData:
	var c := CardData.new("Steadfastness", "{1}{W}", Mtg.CardType.SORCERY)
	c.oracle("Creatures you control get +0/+3 until end of turn.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
