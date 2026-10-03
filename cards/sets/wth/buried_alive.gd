extends CardScript
## Buried Alive — {2}{B} — Sorcery (uncommon, wth).
## Oracle: Search your library for up to three creature cards, put them into your graveyard, then shuffle.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Buried Alive", "{2}{B}", Mtg.CardType.SORCERY)
	c.oracle("Search your library for up to three creature cards, put them into your graveyard, then shuffle.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
