extends CardScript
## Fend Off — {1}{W} — Instant (common, uds).
## Oracle: Prevent all combat damage that would be dealt by target creature this turn.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fend Off", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("Prevent all combat damage that would be dealt by target creature this turn.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
