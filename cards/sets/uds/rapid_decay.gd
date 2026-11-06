extends CardScript
## Rapid Decay — {1}{B} — Instant (rare, uds).
## Oracle: Exile up to three target cards from a single graveyard.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rapid Decay", "{1}{B}", Mtg.CardType.INSTANT)
	c.oracle("Exile up to three target cards from a single graveyard.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
