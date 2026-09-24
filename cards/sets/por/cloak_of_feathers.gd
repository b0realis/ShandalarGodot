extends CardScript
## Cloak of Feathers — {U} — Sorcery (Portal, 1997).
## Oracle: Target creature gains flying until end of turn.
## Oracle: Draw a card.

func build() -> CardData:
	var c := CardData.new("Cloak of Feathers", "{U}", Mtg.CardType.SORCERY)
	c.oracle("Target creature gains flying until end of turn.\nDraw a card.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
