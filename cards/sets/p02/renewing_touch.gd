extends CardScript
## Renewing Touch — {G} — Sorcery (Portal Second Age, 1998).
## Oracle: Shuffle any number of target creature cards from your graveyard into your library.

func build() -> CardData:
	var c := CardData.new("Renewing Touch", "{G}", Mtg.CardType.SORCERY)
	c.oracle("Shuffle any number of target creature cards from your graveyard into your library.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
