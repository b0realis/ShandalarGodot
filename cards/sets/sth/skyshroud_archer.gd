extends CardScript
## Skyshroud Archer — {G} — Creature — Elf Archer (common, sth).
## Oracle: {T}: Target creature with flying gets -1/-1 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Skyshroud Archer", "{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf","archer"])
	c.oracle("{T}: Target creature with flying gets -1/-1 until end of turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
