extends CardScript
## Catalog — {2}{U} — Instant (common, usg).
## Oracle: Draw two cards, then discard a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Catalog", "{2}{U}", Mtg.CardType.INSTANT)
	c.oracle("Draw two cards, then discard a card.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
