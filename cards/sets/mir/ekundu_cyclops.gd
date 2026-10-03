extends CardScript
## Ekundu Cyclops — {3}{R} — Creature — Cyclops (common, mir).
## Oracle: If a creature you control attacks, this creature also attacks if able.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ekundu Cyclops", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["cyclops"])
	c.oracle("If a creature you control attacks, this creature also attacks if able.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
