extends CardScript
## Omen — {1}{U} — Sorcery (Portal, 1997).
## Oracle: Look at the top three cards of your library, then put them back in any order. You may shuffle.
## Oracle: Draw a card.

func build() -> CardData:
	var c := CardData.new("Omen", "{1}{U}", Mtg.CardType.SORCERY)
	c.oracle("Look at the top three cards of your library, then put them back in any order. You may shuffle.\nDraw a card.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
