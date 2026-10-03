extends CardScript
## Yare — {2}{W} — Instant (rare, mir).
## Oracle: Target creature defending player controls gets +3/+0 until end of turn. That creature can block up to two additional creatures this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Yare", "{2}{W}", Mtg.CardType.INSTANT)
	c.oracle("Target creature defending player controls gets +3/+0 until end of turn. That creature can block up to two additional creatures this turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
