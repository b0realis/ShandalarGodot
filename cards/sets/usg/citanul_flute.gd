extends CardScript
## Citanul Flute — {5} — Artifact (rare, usg).
## Oracle: {X}, {T}: Search your library for a creature card with mana value X or less, reveal it, put it into your hand, then shuffle.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Citanul Flute", "{5}", Mtg.CardType.ARTIFACT)
	c.oracle("{X}, {T}: Search your library for a creature card with mana value X or less, reveal it, put it into your hand, then shuffle.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
