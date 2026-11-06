extends CardScript
## Tolarian Winds — {1}{U} — Instant (common, usg).
## Oracle: Discard all the cards in your hand, then draw that many cards.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tolarian Winds", "{1}{U}", Mtg.CardType.INSTANT)
	c.oracle("Discard all the cards in your hand, then draw that many cards.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
