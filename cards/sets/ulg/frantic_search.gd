extends CardScript
## Frantic Search — {2}{U} — Instant (common, ulg).
## Oracle: Draw two cards, then discard two cards. Untap up to three lands.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Frantic Search", "{2}{U}", Mtg.CardType.INSTANT)
	c.oracle("Draw two cards, then discard two cards. Untap up to three lands.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
