extends CardScript
## Aura Thief — {3}{U} — Creature — Illusion (rare, uds).
## Oracle: Flying
##         When this creature dies, you gain control of all enchantments. (You don't get to move Auras.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Aura Thief", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["illusion"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature dies, you gain control of all enchantments. (You don't get to move Auras.)")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
