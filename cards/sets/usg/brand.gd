extends CardScript
## Brand — {R} — Instant (rare, usg).
## Oracle: Gain control of all permanents you own. (This effect lasts indefinitely.)
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Brand", "{R}", Mtg.CardType.INSTANT)
	c.oracle("Gain control of all permanents you own. (This effect lasts indefinitely.)\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
