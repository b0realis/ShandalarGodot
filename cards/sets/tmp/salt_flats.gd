extends CardScript
## Salt Flats —  — Land (rare, tmp).
## Oracle: This land enters tapped.
##         {T}: Add {C}.
##         {T}: Add {W} or {B}. This land deals 1 damage to you.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Salt Flats", "", Mtg.CardType.LAND)
	c.oracle("This land enters tapped.\n{T}: Add {C}.\n{T}: Add {W} or {B}. This land deals 1 damage to you.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
