extends CardScript
## Barreling Attack — {2}{R}{R} — Instant (rare, mir).
## Oracle: Target creature gains trample until end of turn. When that creature becomes blocked this turn, it gets +1/+1 until end of turn for each creature blocking it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Barreling Attack", "{2}{R}{R}", Mtg.CardType.INSTANT)
	c.oracle("Target creature gains trample until end of turn. When that creature becomes blocked this turn, it gets +1/+1 until end of turn for each creature blocking it.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
