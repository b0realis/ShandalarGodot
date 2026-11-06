extends CardScript
## Faerie Conclave —  — Land (uncommon, ulg).
## Oracle: This land enters tapped.
##         {T}: Add {U}.
##         {1}{U}: This land becomes a 2/1 blue Faerie creature with flying until end of turn. It's still a land.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Faerie Conclave", "", Mtg.CardType.LAND)
	c.oracle("This land enters tapped.\n{T}: Add {U}.\n{1}{U}: This land becomes a 2/1 blue Faerie creature with flying until end of turn. It's still a land.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
