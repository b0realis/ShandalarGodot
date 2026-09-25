extends CardScript
## Undo — {1}{U}{U} — Sorcery (Portal Second Age, 1998).
## Oracle: Return two target creatures to their owners' hands.

func build() -> CardData:
	var c := CardData.new("Undo", "{1}{U}{U}", Mtg.CardType.SORCERY)
	c.oracle("Return two target creatures to their owners' hands.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
