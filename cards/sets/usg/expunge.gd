extends CardScript
## Expunge — {2}{B} — Instant (common, usg).
## Oracle: Destroy target nonartifact, nonblack creature. It can't be regenerated.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Expunge", "{2}{B}", Mtg.CardType.INSTANT)
	c.oracle("Destroy target nonartifact, nonblack creature. It can't be regenerated.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
