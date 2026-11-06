extends CardScript
## Horseshoe Crab — {2}{U} — Creature — Crab (common, usg).
## Oracle: {U}: Untap this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Horseshoe Crab", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 3)
	c.with_subtypes(["crab"])
	c.oracle("{U}: Untap this creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
