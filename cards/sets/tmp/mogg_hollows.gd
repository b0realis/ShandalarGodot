extends CardScript
## Mogg Hollows —  — Land (uncommon, tmp).
## Oracle: {T}: Add {C}.
##         {T}: Add {R} or {G}. This land doesn't untap during your next untap step.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mogg Hollows", "", Mtg.CardType.LAND)
	c.oracle("{T}: Add {C}.\n{T}: Add {R} or {G}. This land doesn't untap during your next untap step.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
