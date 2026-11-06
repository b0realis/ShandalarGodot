extends CardScript
## Thran Quarry —  — Land (rare, usg).
## Oracle: At the beginning of the end step, if you control no creatures, sacrifice this land.
##         {T}: Add one mana of any color.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thran Quarry", "", Mtg.CardType.LAND)
	c.oracle("At the beginning of the end step, if you control no creatures, sacrifice this land.\n{T}: Add one mana of any color.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
