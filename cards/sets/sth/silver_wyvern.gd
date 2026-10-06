extends CardScript
## Silver Wyvern — {3}{U}{U} — Creature — Drake (rare, sth).
## Oracle: Flying
##         {U}: Change the target of target spell or ability that targets only this creature. The new target must be a creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Silver Wyvern", "{3}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(4, 3)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{U}: Change the target of target spell or ability that targets only this creature. The new target must be a creature.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
