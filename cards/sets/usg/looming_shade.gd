extends CardScript
## Looming Shade — {2}{B} — Creature — Shade (common, usg).
## Oracle: {B}: This creature gets +1/+1 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Looming Shade", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["shade"])
	c.oracle("{B}: This creature gets +1/+1 until end of turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
