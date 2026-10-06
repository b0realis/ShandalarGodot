extends CardScript
## Endangered Armodon — {2}{G}{G} — Creature — Elephant (common, sth).
## Oracle: When you control a creature with toughness 2 or less, sacrifice this creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Endangered Armodon", "{2}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 5)
	c.with_subtypes(["elephant"])
	c.oracle("When you control a creature with toughness 2 or less, sacrifice this creature.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
