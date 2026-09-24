extends CardScript
## Temporary Truce — {1}{W} — Sorcery (Portal, 1997).
## Oracle: Each player may draw up to two cards. For each card less than two a player draws this way, that player gains 2 life.

func build() -> CardData:
	var c := CardData.new("Temporary Truce", "{1}{W}", Mtg.CardType.SORCERY)
	c.oracle("Each player may draw up to two cards. For each card less than two a player draws this way, that player gains 2 life.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
