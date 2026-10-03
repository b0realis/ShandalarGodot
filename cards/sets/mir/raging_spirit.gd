extends CardScript
## Raging Spirit — {3}{R} — Creature — Spirit (common, mir).
## Oracle: {2}: This creature becomes colorless until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Raging Spirit", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["spirit"])
	c.oracle("{2}: This creature becomes colorless until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
