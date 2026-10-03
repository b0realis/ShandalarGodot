extends CardScript
## Griffin Canyon —  — Land (rare, vis).
## Oracle: {T}: Add {C}.
##         {T}: Untap target Griffin. If it's a creature, it gets +1/+1 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Griffin Canyon", "", Mtg.CardType.LAND)
	c.oracle("{T}: Add {C}.\n{T}: Untap target Griffin. If it's a creature, it gets +1/+1 until end of turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
