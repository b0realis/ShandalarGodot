extends CardScript
## Blasted Landscape —  — Land (uncommon, usg).
## Oracle: {T}: Add {C}.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Blasted Landscape", "", Mtg.CardType.LAND)
	c.oracle("{T}: Add {C}.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
