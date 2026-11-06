extends CardScript
## Might of Oaks — {3}{G} — Instant (rare, ulg).
## Oracle: Target creature gets +7/+7 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Might of Oaks", "{3}{G}", Mtg.CardType.INSTANT)
	c.oracle("Target creature gets +7/+7 until end of turn.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
