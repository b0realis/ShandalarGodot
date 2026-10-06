extends CardScript
## Furnace Brood — {3}{R} — Creature — Elemental (common, exo).
## Oracle: {R}: Target creature can't be regenerated this turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Furnace Brood", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["elemental"])
	c.oracle("{R}: Target creature can't be regenerated this turn.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
