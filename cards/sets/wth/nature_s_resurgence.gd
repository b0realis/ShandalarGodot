extends CardScript
## Nature's Resurgence — {2}{G}{G} — Sorcery (rare, wth).
## Oracle: Each player draws a card for each creature card in their graveyard.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Nature's Resurgence", "{2}{G}{G}", Mtg.CardType.SORCERY)
	c.oracle("Each player draws a card for each creature card in their graveyard.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
