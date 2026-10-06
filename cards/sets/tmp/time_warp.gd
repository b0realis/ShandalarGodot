extends CardScript
## Time Warp — {3}{U}{U} — Sorcery (rare, tmp).
## Oracle: Target player takes an extra turn after this one.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Time Warp", "{3}{U}{U}", Mtg.CardType.SORCERY)
	c.oracle("Target player takes an extra turn after this one.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
