extends CardScript
## Caldera Lake —  — Land (rare, tmp).
## Oracle: This land enters tapped.
##         {T}: Add {C}.
##         {T}: Add {U} or {R}. This land deals 1 damage to you.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Caldera Lake", "", Mtg.CardType.LAND)
	c.oracle("This land enters tapped.\n{T}: Add {C}.\n{T}: Add {U} or {R}. This land deals 1 damage to you.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
