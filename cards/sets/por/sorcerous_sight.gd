extends CardScript
## Sorcerous Sight — {U} — Sorcery (Portal, 1997).
## Oracle: Look at target opponent's hand.
## Oracle: Draw a card.

func build() -> CardData:
	var c := CardData.new("Sorcerous Sight", "{U}", Mtg.CardType.SORCERY)
	c.oracle("Look at target opponent's hand.\nDraw a card.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
