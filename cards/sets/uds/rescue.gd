extends CardScript
## Rescue — {U} — Instant (common, uds).
## Oracle: Return target permanent you control to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rescue", "{U}", Mtg.CardType.INSTANT)
	c.oracle("Return target permanent you control to its owner's hand.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
