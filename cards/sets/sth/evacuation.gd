extends CardScript
## Evacuation — {3}{U}{U} — Instant (rare, sth).
## Oracle: Return all creatures to their owners' hands.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Evacuation", "{3}{U}{U}", Mtg.CardType.INSTANT)
	c.oracle("Return all creatures to their owners' hands.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
