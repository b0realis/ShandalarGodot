extends CardScript
## Smoldering Crater —  — Land (common, usg).
## Oracle: This land enters tapped.
##         {T}: Add {R}.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Smoldering Crater", "", Mtg.CardType.LAND)
	c.oracle("This land enters tapped.\n{T}: Add {R}.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
