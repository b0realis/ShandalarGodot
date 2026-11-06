extends CardScript
## Sick and Tired — {2}{B} — Instant (common, ulg).
## Oracle: Two target creatures each get -1/-1 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sick and Tired", "{2}{B}", Mtg.CardType.INSTANT)
	c.oracle("Two target creatures each get -1/-1 until end of turn.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
