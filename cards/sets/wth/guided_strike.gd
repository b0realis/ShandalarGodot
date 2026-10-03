extends CardScript
## Guided Strike — {1}{W} — Instant (common, wth).
## Oracle: Target creature gets +1/+0 and gains first strike until end of turn.
##         Draw a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Guided Strike", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("Target creature gets +1/+0 and gains first strike until end of turn.\nDraw a card.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
