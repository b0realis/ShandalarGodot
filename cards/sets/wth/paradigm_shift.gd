extends CardScript
## Paradigm Shift — {1}{U} — Sorcery (rare, wth).
## Oracle: Exile all cards from your library. Then shuffle your graveyard into your library.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Paradigm Shift", "{1}{U}", Mtg.CardType.SORCERY)
	c.oracle("Exile all cards from your library. Then shuffle your graveyard into your library.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
