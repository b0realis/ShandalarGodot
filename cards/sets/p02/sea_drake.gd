extends CardScript
## Sea Drake — {2}{U} — Creature — Drake — 4/3 (Portal Second Age, 1998).
## Oracle: Flying
## Oracle: When this creature enters, return two target lands you control to their owner's hand.

func build() -> CardData:
	var c := CardData.new("Sea Drake", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(4, 3)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, return two target lands you control to their owner's hand.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
