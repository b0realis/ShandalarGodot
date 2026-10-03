extends CardScript
## Dwarven Nomad — {2}{R} — Creature — Dwarf Nomad (common, mir).
## Oracle: {T}: Target creature with power 2 or less can't be blocked this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dwarven Nomad", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["dwarf","nomad"])
	c.oracle("{T}: Target creature with power 2 or less can't be blocked this turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
