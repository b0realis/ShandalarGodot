extends CardScript
## Lightning Elemental — {3}{R} — Creature — Elemental (common, tmp).
## Oracle: Haste (This creature can attack and {T} as soon as it comes under your control.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lightning Elemental", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 1)
	c.with_subtypes(["elemental"])
	c.with_keywords([Mtg.Keyword.HASTE])
	c.oracle("Haste (This creature can attack and {T} as soon as it comes under your control.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
