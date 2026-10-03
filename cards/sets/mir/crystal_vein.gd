extends CardScript
## Crystal Vein —  — Land (uncommon, mir).
## Oracle: {T}: Add {C}.
##         {T}, Sacrifice this land: Add {C}{C}.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Crystal Vein", "", Mtg.CardType.LAND)
	c.oracle("{T}: Add {C}.\n{T}, Sacrifice this land: Add {C}{C}.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
