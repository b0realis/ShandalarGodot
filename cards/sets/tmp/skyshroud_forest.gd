extends CardScript
## Skyshroud Forest —  — Land (rare, tmp).
## Oracle: This land enters tapped.
##         {T}: Add {C}.
##         {T}: Add {G} or {U}. This land deals 1 damage to you.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Skyshroud Forest", "", Mtg.CardType.LAND)
	c.oracle("This land enters tapped.\n{T}: Add {C}.\n{T}: Add {G} or {U}. This land deals 1 damage to you.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
