extends CardScript
## Zuberi, Golden Feather — {4}{W} — Legendary Creature — Griffin (rare, mir).
## Oracle: Flying
##         Other Griffin creatures get +1/+1.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Zuberi, Golden Feather", "{4}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["griffin"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nOther Griffin creatures get +1/+1.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
