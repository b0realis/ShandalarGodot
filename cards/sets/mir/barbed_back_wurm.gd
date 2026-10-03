extends CardScript
## Barbed-Back Wurm — {4}{B} — Creature — Wurm (uncommon, mir).
## Oracle: {B}: Target green creature blocking this creature gets -1/-1 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Barbed-Back Wurm", "{4}{B}", Mtg.CardType.CREATURE)
	c.pt(4, 3)
	c.with_subtypes(["wurm"])
	c.oracle("{B}: Target green creature blocking this creature gets -1/-1 until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
