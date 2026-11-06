extends CardScript
## Tolarian Academy —  — Legendary Land (rare, usg).
## Oracle: {T}: Add {U} for each artifact you control.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tolarian Academy", "", Mtg.CardType.LAND)
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("{T}: Add {U} for each artifact you control.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
