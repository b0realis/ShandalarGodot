extends CardScript
## Flame Elemental — {2}{R}{R} — Creature — Elemental (uncommon, mir).
## Oracle: {R}, {T}, Sacrifice this creature: It deals damage equal to its power to target creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flame Elemental", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["elemental"])
	c.oracle("{R}, {T}, Sacrifice this creature: It deals damage equal to its power to target creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
