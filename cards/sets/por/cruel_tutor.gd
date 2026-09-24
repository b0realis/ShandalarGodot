extends CardScript
## Cruel Tutor — {2}{B} — Sorcery (Portal, 1997).
## Oracle: Search your library for a card, then shuffle and put that card on top. You lose 2 life.

func build() -> CardData:
	var c := CardData.new("Cruel Tutor", "{2}{B}", Mtg.CardType.SORCERY)
	c.oracle("Search your library for a card, then shuffle and put that card on top. You lose 2 life.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
