extends CardScript
## Festival of Trokin — {W} — Sorcery (Portal Second Age, 1998).
## Oracle: You gain 2 life for each creature you control.

func build() -> CardData:
	var c := CardData.new("Festival of Trokin", "{W}", Mtg.CardType.SORCERY)
	c.oracle("You gain 2 life for each creature you control.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
