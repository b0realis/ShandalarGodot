extends CardScript
## Time Ebb — {2}{U} — Sorcery (Portal, 1997).
## Oracle: Put target creature on top of its owner's library.

func build() -> CardData:
	var c := CardData.new("Time Ebb", "{2}{U}", Mtg.CardType.SORCERY)
	c.oracle("Put target creature on top of its owner's library.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
