extends CardScript
## Stun — {1}{R} — Instant (common, tmp).
## Oracle: Target creature can't block this turn.
##         Draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Stun", "{1}{R}", Mtg.CardType.INSTANT)
	c.oracle("Target creature can't block this turn.\nDraw a card.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
