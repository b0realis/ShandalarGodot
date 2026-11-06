extends CardScript
## Miscalculation — {1}{U} — Instant (common, ulg).
## Oracle: Counter target spell unless its controller pays {2}.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Miscalculation", "{1}{U}", Mtg.CardType.INSTANT)
	c.oracle("Counter target spell unless its controller pays {2}.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
