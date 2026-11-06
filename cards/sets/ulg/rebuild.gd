extends CardScript
## Rebuild — {2}{U} — Instant (uncommon, ulg).
## Oracle: Return all artifacts to their owners' hands.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rebuild", "{2}{U}", Mtg.CardType.INSTANT)
	c.oracle("Return all artifacts to their owners' hands.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
