extends CardScript
## Tethered Griffin — {W} — Creature — Griffin (rare, uds).
## Oracle: Flying
##         When you control no enchantments, sacrifice this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tethered Griffin", "{W}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["griffin"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen you control no enchantments, sacrifice this creature.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
