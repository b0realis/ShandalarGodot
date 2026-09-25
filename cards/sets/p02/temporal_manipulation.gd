extends CardScript
## Temporal Manipulation — {3}{U}{U} — Sorcery (Portal Second Age, 1998).
## Oracle: Take an extra turn after this one.

func build() -> CardData:
	var c := CardData.new("Temporal Manipulation", "{3}{U}{U}", Mtg.CardType.SORCERY)
	c.oracle("Take an extra turn after this one.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
