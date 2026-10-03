extends CardScript
## Dwarven Berserker — {1}{R} — Creature — Dwarf Berserker (common, wth).
## Oracle: Whenever this creature becomes blocked, it gets +3/+0 and gains trample until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dwarven Berserker", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["dwarf","berserker"])
	c.oracle("Whenever this creature becomes blocked, it gets +3/+0 and gains trample until end of turn.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
