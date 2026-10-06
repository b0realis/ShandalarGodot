extends CardScript
## Gallantry — {1}{W} — Instant (uncommon, tmp).
## Oracle: Target blocking creature gets +4/+4 until end of turn.
##         Draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Gallantry", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("Target blocking creature gets +4/+4 until end of turn.\nDraw a card.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
