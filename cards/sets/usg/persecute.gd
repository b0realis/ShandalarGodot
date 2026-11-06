extends CardScript
## Persecute — {2}{B}{B} — Sorcery (rare, usg).
## Oracle: Choose a color. Target player reveals their hand and discards all cards of that color.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Persecute", "{2}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Choose a color. Target player reveals their hand and discards all cards of that color.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
