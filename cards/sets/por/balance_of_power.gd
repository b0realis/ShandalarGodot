extends CardScript
## Balance of Power — {3}{U}{U} — Sorcery (Portal, 1997).
## Oracle: If target opponent has more cards in hand than you, draw cards equal to the difference.

func build() -> CardData:
	var c := CardData.new("Balance of Power", "{3}{U}{U}", Mtg.CardType.SORCERY)
	c.oracle("If target opponent has more cards in hand than you, draw cards equal to the difference.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
