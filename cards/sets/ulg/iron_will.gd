extends CardScript
## Iron Will — {W} — Instant (common, ulg).
## Oracle: Target creature gets +0/+4 until end of turn.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Iron Will", "{W}", Mtg.CardType.INSTANT)
	c.oracle("Target creature gets +0/+4 until end of turn.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
