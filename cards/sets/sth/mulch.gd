extends CardScript
## Mulch — {1}{G} — Sorcery (common, sth).
## Oracle: Reveal the top four cards of your library. Put all land cards revealed this way into your hand and the rest into your graveyard.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mulch", "{1}{G}", Mtg.CardType.SORCERY)
	c.oracle("Reveal the top four cards of your library. Put all land cards revealed this way into your hand and the rest into your graveyard.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
