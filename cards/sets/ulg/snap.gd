extends CardScript
## Snap — {1}{U} — Instant (common, ulg).
## Oracle: Return target creature to its owner's hand. Untap up to two lands.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Snap", "{1}{U}", Mtg.CardType.INSTANT)
	c.oracle("Return target creature to its owner's hand. Untap up to two lands.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
