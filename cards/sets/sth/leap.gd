extends CardScript
## Leap — {U} — Instant (common, sth).
## Oracle: Target creature gains flying until end of turn.
##         Draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Leap", "{U}", Mtg.CardType.INSTANT)
	c.oracle("Target creature gains flying until end of turn.\nDraw a card.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
