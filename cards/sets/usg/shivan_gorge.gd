extends CardScript
## Shivan Gorge —  — Legendary Land (rare, usg).
## Oracle: {T}: Add {C}.
##         {2}{R}, {T}: Shivan Gorge deals 1 damage to each opponent.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shivan Gorge", "", Mtg.CardType.LAND)
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("{T}: Add {C}.\n{2}{R}, {T}: Shivan Gorge deals 1 damage to each opponent.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
