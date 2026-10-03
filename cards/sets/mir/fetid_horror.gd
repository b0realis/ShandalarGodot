extends CardScript
## Fetid Horror — {3}{B} — Creature — Shade Horror (common, mir).
## Oracle: {B}: This creature gets +1/+1 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fetid Horror", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["shade","horror"])
	c.oracle("{B}: This creature gets +1/+1 until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
