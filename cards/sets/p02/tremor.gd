extends CardScript
## Tremor — {R} — Sorcery (Portal Second Age, 1998).
## Oracle: Tremor deals 1 damage to each creature without flying.

func build() -> CardData:
	var c := CardData.new("Tremor", "{R}", Mtg.CardType.SORCERY)
	c.oracle("Tremor deals 1 damage to each creature without flying.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
