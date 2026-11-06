extends CardScript
## Swat — {1}{B}{B} — Instant (common, ulg).
## Oracle: Destroy target creature with power 2 or less.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Swat", "{1}{B}{B}", Mtg.CardType.INSTANT)
	c.oracle("Destroy target creature with power 2 or less.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
