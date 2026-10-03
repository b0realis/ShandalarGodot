extends CardScript
## Gemstone Mine —  — Land (uncommon, wth).
## Oracle: This land enters with three mining counters on it.
##         {T}, Remove a mining counter from this land: Add one mana of any color. If there are no mining counters on this land, sacrifice it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Gemstone Mine", "", Mtg.CardType.LAND)
	c.oracle("This land enters with three mining counters on it.\n{T}, Remove a mining counter from this land: Add one mana of any color. If there are no mining counters on this land, sacrifice it.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
