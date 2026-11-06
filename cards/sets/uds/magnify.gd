extends CardScript
## Magnify — {G} — Instant (common, uds).
## Oracle: All creatures get +1/+1 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Magnify", "{G}", Mtg.CardType.INSTANT)
	c.oracle("All creatures get +1/+1 until end of turn.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
