extends CardScript
## Timid Drake — {2}{U} — Creature — Drake (uncommon, wth).
## Oracle: Flying
##         When another creature enters, return this creature to its owner's hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Timid Drake", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen another creature enters, return this creature to its owner's hand.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
