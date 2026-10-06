extends CardScript
## Mana Severance — {1}{U} — Sorcery (rare, tmp).
## Oracle: Search your library for any number of land cards, exile them, then shuffle.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mana Severance", "{1}{U}", Mtg.CardType.SORCERY)
	c.oracle("Search your library for any number of land cards, exile them, then shuffle.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
