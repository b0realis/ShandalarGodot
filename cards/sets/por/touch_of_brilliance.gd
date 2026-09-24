extends CardScript
## Touch of Brilliance — {3}{U} — Sorcery (Portal, 1997).
## Oracle: Draw two cards.

func build() -> CardData:
	var c := CardData.new("Touch of Brilliance", "{3}{U}", Mtg.CardType.SORCERY)
	c.oracle("Draw two cards.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
