extends CardScript
## Yavimaya Hollow —  — Legendary Land (rare, uds).
## Oracle: {T}: Add {C}.
##         {G}, {T}: Regenerate target creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Yavimaya Hollow", "", Mtg.CardType.LAND)
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("{T}: Add {C}.\n{G}, {T}: Regenerate target creature.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
