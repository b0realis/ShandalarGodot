extends CardScript
## Quicksand —  — Land (uncommon, vis).
## Oracle: {T}: Add {C}.
##         {T}, Sacrifice this land: Target attacking creature without flying gets -1/-2 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Quicksand", "", Mtg.CardType.LAND)
	c.oracle("{T}: Add {C}.\n{T}, Sacrifice this land: Target attacking creature without flying gets -1/-2 until end of turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
