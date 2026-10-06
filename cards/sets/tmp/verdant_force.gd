extends CardScript
## Verdant Force — {5}{G}{G}{G} — Creature — Elemental (rare, tmp).
## Oracle: At the beginning of each upkeep, create a 1/1 green Saproling creature token.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Verdant Force", "{5}{G}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(7, 7)
	c.with_subtypes(["elemental"])
	c.oracle("At the beginning of each upkeep, create a 1/1 green Saproling creature token.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
