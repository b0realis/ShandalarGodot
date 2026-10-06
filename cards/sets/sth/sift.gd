extends CardScript
## Sift — {3}{U} — Sorcery (common, sth).
## Oracle: Draw three cards, then discard a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sift", "{3}{U}", Mtg.CardType.SORCERY)
	c.oracle("Draw three cards, then discard a card.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
