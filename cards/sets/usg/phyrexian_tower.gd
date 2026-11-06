extends CardScript
## Phyrexian Tower —  — Legendary Land (rare, usg).
## Oracle: {T}: Add {C}.
##         {T}, Sacrifice a creature: Add {B}{B}.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Tower", "", Mtg.CardType.LAND)
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("{T}: Add {C}.\n{T}, Sacrifice a creature: Add {B}{B}.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
