extends CardScript
## Reality Anchor — {1}{G} — Instant (common, tmp).
## Oracle: Target creature loses shadow until end of turn.
##         Draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reality Anchor", "{1}{G}", Mtg.CardType.INSTANT)
	c.oracle("Target creature loses shadow until end of turn.\nDraw a card.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
