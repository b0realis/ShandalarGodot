extends CardScript
## Boiling Blood — {2}{R} — Instant (common, wth).
## Oracle: Target creature attacks this turn if able.
##         Draw a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Boiling Blood", "{2}{R}", Mtg.CardType.INSTANT)
	c.oracle("Target creature attacks this turn if able.\nDraw a card.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
