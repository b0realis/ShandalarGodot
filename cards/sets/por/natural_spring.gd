extends CardScript
## Natural Spring — {3}{G}{G} — Sorcery (Portal, 1997).
## Oracle: Target player gains 8 life.

func build() -> CardData:
	var c := CardData.new("Natural Spring", "{3}{G}{G}", Mtg.CardType.SORCERY)
	c.oracle("Target player gains 8 life.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
