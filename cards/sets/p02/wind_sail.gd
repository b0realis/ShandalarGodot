extends CardScript
## Wind Sail — {1}{U} — Sorcery (Portal Second Age, 1998).
## Oracle: One or two target creatures gain flying until end of turn.

func build() -> CardData:
	var c := CardData.new("Wind Sail", "{1}{U}", Mtg.CardType.SORCERY)
	c.oracle("One or two target creatures gain flying until end of turn.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
