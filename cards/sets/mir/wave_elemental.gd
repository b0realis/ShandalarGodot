extends CardScript
## Wave Elemental — {2}{U}{U} — Creature — Elemental (uncommon, mir).
## Oracle: {U}, {T}, Sacrifice this creature: Tap up to three target creatures without flying.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wave Elemental", "{2}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["elemental"])
	c.oracle("{U}, {T}, Sacrifice this creature: Tap up to three target creatures without flying.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
