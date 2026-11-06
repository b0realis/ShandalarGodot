extends CardScript
## Trumpet Blast — {2}{R} — Instant (common, uds).
## Oracle: Attacking creatures get +2/+0 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Trumpet Blast", "{2}{R}", Mtg.CardType.INSTANT)
	c.oracle("Attacking creatures get +2/+0 until end of turn.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
