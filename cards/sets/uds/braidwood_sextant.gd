extends CardScript
## Braidwood Sextant — {1} — Artifact (uncommon, uds).
## Oracle: {2}, {T}, Sacrifice this artifact: Search your library for a basic land card, reveal that card, put it into your hand, then shuffle.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Braidwood Sextant", "{1}", Mtg.CardType.ARTIFACT)
	c.oracle("{2}, {T}, Sacrifice this artifact: Search your library for a basic land card, reveal that card, put it into your hand, then shuffle.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
