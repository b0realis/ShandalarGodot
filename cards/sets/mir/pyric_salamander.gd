extends CardScript
## Pyric Salamander — {1}{R} — Creature — Salamander (common, mir).
## Oracle: {R}: This creature gets +1/+0 until end of turn. Sacrifice this creature at the beginning of the next end step.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pyric Salamander", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["salamander"])
	c.oracle("{R}: This creature gets +1/+0 until end of turn. Sacrifice this creature at the beginning of the next end step.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
