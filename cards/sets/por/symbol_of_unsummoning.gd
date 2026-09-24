extends CardScript
## Symbol of Unsummoning — {2}{U} — Sorcery (Portal, 1997).
## Oracle: Return target creature to its owner's hand.
## Oracle: Draw a card.

func build() -> CardData:
	var c := CardData.new("Symbol of Unsummoning", "{2}{U}", Mtg.CardType.SORCERY)
	c.oracle("Return target creature to its owner's hand.\nDraw a card.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
