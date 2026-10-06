extends CardScript
## Shadow Rift — {U} — Instant (common, tmp).
## Oracle: Target creature gains shadow until end of turn. (It can block or be blocked by only creatures with shadow.)
##         Draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shadow Rift", "{U}", Mtg.CardType.INSTANT)
	c.oracle("Target creature gains shadow until end of turn. (It can block or be blocked by only creatures with shadow.)\nDraw a card.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
