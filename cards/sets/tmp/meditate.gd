extends CardScript
## Meditate — {2}{U} — Instant (rare, tmp).
## Oracle: Draw four cards. You skip your next turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Meditate", "{2}{U}", Mtg.CardType.INSTANT)
	c.oracle("Draw four cards. You skip your next turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
