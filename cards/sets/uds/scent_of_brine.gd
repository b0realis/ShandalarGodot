extends CardScript
## Scent of Brine — {1}{U} — Instant (common, uds).
## Oracle: Reveal any number of blue cards in your hand. Counter target spell unless its controller pays {1} for each card revealed this way.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scent of Brine", "{1}{U}", Mtg.CardType.INSTANT)
	c.oracle("Reveal any number of blue cards in your hand. Counter target spell unless its controller pays {1} for each card revealed this way.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
