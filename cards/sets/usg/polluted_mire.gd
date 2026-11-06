extends CardScript
## Polluted Mire —  — Land (common, usg).
## Oracle: This land enters tapped.
##         {T}: Add {B}.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Polluted Mire", "", Mtg.CardType.LAND)
	c.oracle("This land enters tapped.\n{T}: Add {B}.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
