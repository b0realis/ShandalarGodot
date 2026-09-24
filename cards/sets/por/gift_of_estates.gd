extends CardScript
## Gift of Estates — {1}{W} — Sorcery (Portal, 1997).
## Oracle: If an opponent controls more lands than you, search your library for up to three Plains cards, reveal them, put them into your hand, then shuffle.

func build() -> CardData:
	var c := CardData.new("Gift of Estates", "{1}{W}", Mtg.CardType.SORCERY)
	c.oracle("If an opponent controls more lands than you, search your library for up to three Plains cards, reveal them, put them into your hand, then shuffle.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
