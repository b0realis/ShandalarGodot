extends CardScript
## Ancient Tomb —  — Land (uncommon, tmp).
## Oracle: {T}: Add {C}{C}. This land deals 2 damage to you.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ancient Tomb", "", Mtg.CardType.LAND)
	c.oracle("{T}: Add {C}{C}. This land deals 2 damage to you.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
