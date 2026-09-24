extends CardScript
## Forked Lightning — {3}{R} — Sorcery (Portal, 1997).
## Oracle: Forked Lightning deals 4 damage divided as you choose among one, two, or three target creatures.

func build() -> CardData:
	var c := CardData.new("Forked Lightning", "{3}{R}", Mtg.CardType.SORCERY)
	c.oracle("Forked Lightning deals 4 damage divided as you choose among one, two, or three target creatures.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
