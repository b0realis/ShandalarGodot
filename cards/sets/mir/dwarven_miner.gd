extends CardScript
## Dwarven Miner — {1}{R} — Creature — Dwarf (uncommon, mir).
## Oracle: {2}{R}, {T}: Destroy target nonbasic land.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dwarven Miner", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["dwarf"])
	c.oracle("{2}{R}, {T}: Destroy target nonbasic land.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
