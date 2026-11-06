extends CardScript
## Thornwind Faeries — {1}{U}{U} — Creature — Faerie (common, ulg).
## Oracle: Flying
##         {T}: This creature deals 1 damage to any target.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thornwind Faeries", "{1}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["faerie"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{T}: This creature deals 1 damage to any target.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
