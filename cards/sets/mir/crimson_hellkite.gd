extends CardScript
## Crimson Hellkite — {6}{R}{R}{R} — Creature — Dragon (rare, mir).
## Oracle: Flying
##         {X}, {T}: This creature deals X damage to target creature. Spend only red mana on X.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Crimson Hellkite", "{6}{R}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(6, 6)
	c.with_subtypes(["dragon"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{X}, {T}: This creature deals X damage to target creature. Spend only red mana on X.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
