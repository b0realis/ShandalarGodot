extends CardScript
## Bellowing Fiend — {4}{B} — Creature — Spirit (rare, tmp).
## Oracle: Flying
##         Whenever this creature deals damage to a creature, this creature deals 3 damage to that creature's controller and 3 damage to you.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bellowing Fiend", "{4}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhenever this creature deals damage to a creature, this creature deals 3 damage to that creature's controller and 3 damage to you.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
