extends CardScript
## Rescind — {1}{U}{U} — Instant (common, usg).
## Oracle: Return target permanent to its owner's hand.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rescind", "{1}{U}{U}", Mtg.CardType.INSTANT)
	c.oracle("Return target permanent to its owner's hand.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
