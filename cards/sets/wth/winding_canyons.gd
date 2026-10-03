extends CardScript
## Winding Canyons —  — Land (rare, wth).
## Oracle: {T}: Add {C}.
##         {2}, {T}: You may cast creature spells this turn as though they had flash.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Winding Canyons", "", Mtg.CardType.LAND)
	c.oracle("{T}: Add {C}.\n{2}, {T}: You may cast creature spells this turn as though they had flash.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
