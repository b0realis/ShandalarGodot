extends CardScript
## Serra's Sanctum —  — Legendary Land (rare, usg).
## Oracle: {T}: Add {W} for each enchantment you control.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Serra's Sanctum", "", Mtg.CardType.LAND)
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("{T}: Add {W} for each enchantment you control.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
