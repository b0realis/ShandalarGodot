extends CardScript
## Giant Crab — {4}{U} — Creature — Crab (common, tmp).
## Oracle: {U}: This creature gains shroud until end of turn. (It can't be the target of spells or abilities.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Giant Crab", "{4}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["crab"])
	c.oracle("{U}: This creature gains shroud until end of turn. (It can't be the target of spells or abilities.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
