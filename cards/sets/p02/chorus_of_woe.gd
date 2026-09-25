extends CardScript
## Chorus of Woe — {B} — Sorcery (Portal Second Age, 1998).
## Oracle: Creatures you control get +1/+0 until end of turn.

func build() -> CardData:
	var c := CardData.new("Chorus of Woe", "{B}", Mtg.CardType.SORCERY)
	c.oracle("Creatures you control get +1/+0 until end of turn.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
