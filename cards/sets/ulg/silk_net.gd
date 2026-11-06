extends CardScript
## Silk Net — {G} — Instant (common, ulg).
## Oracle: Target creature gets +1/+1 and gains reach until end of turn. (It can block creatures with flying.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Silk Net", "{G}", Mtg.CardType.INSTANT)
	c.oracle("Target creature gets +1/+1 and gains reach until end of turn. (It can block creatures with flying.)")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
