extends CardScript
## Reflecting Pool —  — Land (rare, tmp).
## Oracle: {T}: Add one mana of any type that a land you control could produce.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reflecting Pool", "", Mtg.CardType.LAND)
	c.oracle("{T}: Add one mana of any type that a land you control could produce.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
