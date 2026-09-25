extends CardScript
## Righteous Charge — {1}{W}{W} — Sorcery (Portal Second Age, 1998).
## Oracle: Creatures you control get +2/+2 until end of turn.

func build() -> CardData:
	var c := CardData.new("Righteous Charge", "{1}{W}{W}", Mtg.CardType.SORCERY)
	c.oracle("Creatures you control get +2/+2 until end of turn.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
