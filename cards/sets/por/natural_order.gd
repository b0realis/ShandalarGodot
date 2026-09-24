extends CardScript
## Natural Order — {2}{G}{G} — Sorcery (Portal, 1997).
## Oracle: As an additional cost to cast this spell, sacrifice a green creature.
## Oracle: Search your library for a green creature card, put it onto the battlefield, then shuffle.

func build() -> CardData:
	var c := CardData.new("Natural Order", "{2}{G}{G}", Mtg.CardType.SORCERY)
	c.oracle("As an additional cost to cast this spell, sacrifice a green creature.\nSearch your library for a green creature card, put it onto the battlefield, then shuffle.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
