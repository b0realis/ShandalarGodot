extends CardScript
## Breathstealer — {2}{B} — Creature — Nightstalker (common, mir).
## Oracle: {B}: This creature gets +1/-1 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Breathstealer", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["nightstalker"])
	c.oracle("{B}: This creature gets +1/-1 until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
