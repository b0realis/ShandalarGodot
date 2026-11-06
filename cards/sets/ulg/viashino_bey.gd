extends CardScript
## Viashino Bey — {2}{R}{R} — Creature — Lizard (common, ulg).
## Oracle: If this creature attacks, all creatures you control attack if able.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Viashino Bey", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 3)
	c.with_subtypes(["lizard"])
	c.oracle("If this creature attacks, all creatures you control attack if able.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
