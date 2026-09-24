extends CardScript
## Devastation — {5}{R}{R} — Sorcery (Portal, 1997).
## Oracle: Destroy all creatures and lands.

func build() -> CardData:
	var c := CardData.new("Devastation", "{5}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all creatures and lands.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
