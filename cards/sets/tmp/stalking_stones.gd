extends CardScript
## Stalking Stones —  — Land (uncommon, tmp).
## Oracle: {T}: Add {C}.
##         {6}: This land becomes a 3/3 Elemental artifact creature that's still a land. (This effect lasts indefinitely.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Stalking Stones", "", Mtg.CardType.LAND)
	c.oracle("{T}: Add {C}.\n{6}: This land becomes a 3/3 Elemental artifact creature that's still a land. (This effect lasts indefinitely.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
