extends CardScript
## Flood Plain —  — Land (uncommon, mir).
## Oracle: This land enters tapped.
##         {T}, Sacrifice this land: Search your library for a Plains or Island card, put it onto the battlefield, then shuffle.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flood Plain", "", Mtg.CardType.LAND)
	c.oracle("This land enters tapped.\n{T}, Sacrifice this land: Search your library for a Plains or Island card, put it onto the battlefield, then shuffle.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
