extends CardScript
## Salvage — {G} — Sorcery (Portal Second Age, 1998).
## Oracle: Put target card from your graveyard on top of your library.

func build() -> CardData:
	var c := CardData.new("Salvage", "{G}", Mtg.CardType.SORCERY)
	c.oracle("Put target card from your graveyard on top of your library.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
