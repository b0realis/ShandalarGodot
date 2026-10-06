extends CardScript
## Ghost Town —  — Land (uncommon, tmp).
## Oracle: {T}: Add {C}.
##         {0}: Return this land to its owner's hand. Activate only if it's not your turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ghost Town", "", Mtg.CardType.LAND)
	c.oracle("{T}: Add {C}.\n{0}: Return this land to its owner's hand. Activate only if it's not your turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
