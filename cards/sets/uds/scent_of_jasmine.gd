extends CardScript
## Scent of Jasmine — {W} — Instant (common, uds).
## Oracle: Reveal any number of white cards in your hand. You gain 2 life for each card revealed this way.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scent of Jasmine", "{W}", Mtg.CardType.INSTANT)
	c.oracle("Reveal any number of white cards in your hand. You gain 2 life for each card revealed this way.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
