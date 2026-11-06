extends CardScript
## Zephid — {4}{U}{U} — Creature — Illusion (rare, usg).
## Oracle: Flying
##         Shroud (This creature can't be the target of spells or abilities.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Zephid", "{4}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["illusion"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nShroud (This creature can't be the target of spells or abilities.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
