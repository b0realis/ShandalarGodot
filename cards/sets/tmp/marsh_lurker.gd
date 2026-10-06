extends CardScript
## Marsh Lurker — {3}{B} — Creature — Beast (common, tmp).
## Oracle: Sacrifice a Swamp: This creature gains fear until end of turn. (It can't be blocked except by artifact creatures and/or black creatures.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Marsh Lurker", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["beast"])
	c.oracle("Sacrifice a Swamp: This creature gains fear until end of turn. (It can't be blocked except by artifact creatures and/or black creatures.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
