extends CardScript
## Soul Feast — {3}{B}{B} — Sorcery (uncommon, uds).
## Oracle: Target player loses 4 life and you gain 4 life.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Soul Feast", "{3}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Target player loses 4 life and you gain 4 life.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
