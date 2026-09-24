extends CardScript
## Flux — {2}{U} — Sorcery (Portal, 1997).
## Oracle: Each player discards any number of cards, then draws that many cards.
## Oracle: Draw a card.

func build() -> CardData:
	var c := CardData.new("Flux", "{2}{U}", Mtg.CardType.SORCERY)
	c.oracle("Each player discards any number of cards, then draws that many cards.\nDraw a card.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
