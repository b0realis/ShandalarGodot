extends CardScript
## Dwarven Thaumaturgist — {2}{R} — Creature — Dwarf Shaman (rare, wth).
## Oracle: {T}: Switch target creature's power and toughness until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dwarven Thaumaturgist", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["dwarf","shaman"])
	c.oracle("{T}: Switch target creature's power and toughness until end of turn.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
