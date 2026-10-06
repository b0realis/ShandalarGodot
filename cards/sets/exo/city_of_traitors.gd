extends CardScript
## City of Traitors —  — Land (rare, exo).
## Oracle: When you play another land, sacrifice this land.
##         {T}: Add {C}{C}.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("City of Traitors", "", Mtg.CardType.LAND)
	c.oracle("When you play another land, sacrifice this land.\n{T}: Add {C}{C}.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
