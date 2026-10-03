extends CardScript
## Shrieking Drake — {U} — Creature — Drake (common, vis).
## Oracle: Flying
##         When this creature enters, return a creature you control to its owner's hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shrieking Drake", "{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, return a creature you control to its owner's hand.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
