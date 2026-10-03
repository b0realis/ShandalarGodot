extends CardScript
## Jabari's Influence — {3}{W}{W} — Instant (rare, mir).
## Oracle: Cast this spell only after combat.
##         Gain control of target nonartifact, nonblack creature that attacked you this turn and put a -1/-0 counter on it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Jabari's Influence", "{3}{W}{W}", Mtg.CardType.INSTANT)
	c.oracle("Cast this spell only after combat.\nGain control of target nonartifact, nonblack creature that attacked you this turn and put a -1/-0 counter on it.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
