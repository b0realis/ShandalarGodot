extends CardScript
## Ancient Craving — {3}{B} — Sorcery (Portal Second Age, 1998).
## Oracle: You draw three cards and you lose 3 life.

func build() -> CardData:
	var c := CardData.new("Ancient Craving", "{3}{B}", Mtg.CardType.SORCERY)
	c.oracle("You draw three cards and you lose 3 life.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
