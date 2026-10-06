extends CardScript
## Mawcor — {3}{U}{U} — Creature — Beast (rare, tmp).
## Oracle: Flying
##         {T}: This creature deals 1 damage to any target.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mawcor", "{3}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["beast"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{T}: This creature deals 1 damage to any target.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
