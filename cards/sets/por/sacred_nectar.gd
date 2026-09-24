extends CardScript
## Sacred Nectar — {1}{W} — Sorcery (Portal, 1997).
## Oracle: You gain 4 life.

func build() -> CardData:
	var c := CardData.new("Sacred Nectar", "{1}{W}", Mtg.CardType.SORCERY)
	c.oracle("You gain 4 life.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
