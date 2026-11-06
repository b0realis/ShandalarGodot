extends CardScript
## Sunder — {3}{U}{U} — Instant (rare, usg).
## Oracle: Return all lands to their owners' hands.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sunder", "{3}{U}{U}", Mtg.CardType.INSTANT)
	c.oracle("Return all lands to their owners' hands.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
