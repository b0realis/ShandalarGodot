extends CardScript
## Shattered Crypt — {X}{B}{B} — Sorcery (common, wth).
## Oracle: Return X target creature cards from your graveyard to your hand. You lose X life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shattered Crypt", "{X}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Return X target creature cards from your graveyard to your hand. You lose X life.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
