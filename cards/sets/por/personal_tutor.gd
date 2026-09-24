extends CardScript
## Personal Tutor — {U} — Sorcery (Portal, 1997).
## Oracle: Search your library for a sorcery card, reveal it, then shuffle and put that card on top.

func build() -> CardData:
	var c := CardData.new("Personal Tutor", "{U}", Mtg.CardType.SORCERY)
	c.oracle("Search your library for a sorcery card, reveal it, then shuffle and put that card on top.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
