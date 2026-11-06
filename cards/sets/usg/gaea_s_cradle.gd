extends CardScript
## Gaea's Cradle —  — Legendary Land (rare, usg).
## Oracle: {T}: Add {G} for each creature you control.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Gaea's Cradle", "", Mtg.CardType.LAND)
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("{T}: Add {G} for each creature you control.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
