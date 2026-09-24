extends CardScript
## Path of Peace — {3}{W} — Sorcery (Portal, 1997).
## Oracle: Destroy target creature. Its owner gains 4 life.

func build() -> CardData:
	var c := CardData.new("Path of Peace", "{3}{W}", Mtg.CardType.SORCERY)
	c.oracle("Destroy target creature. Its owner gains 4 life.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
