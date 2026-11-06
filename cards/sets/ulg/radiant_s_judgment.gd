extends CardScript
## Radiant's Judgment — {2}{W} — Instant (common, ulg).
## Oracle: Destroy target creature with power 4 or greater.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Radiant's Judgment", "{2}{W}", Mtg.CardType.INSTANT)
	c.oracle("Destroy target creature with power 4 or greater.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
