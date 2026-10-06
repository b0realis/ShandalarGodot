extends CardScript
## Wasteland —  — Land (uncommon, tmp).
## Oracle: {T}: Add {C}.
##         {T}, Sacrifice this land: Destroy target nonbasic land.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wasteland", "", Mtg.CardType.LAND)
	c.oracle("{T}: Add {C}.\n{T}, Sacrifice this land: Destroy target nonbasic land.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
