extends CardScript
## Fog Elemental — {2}{U} — Creature — Elemental (common, wth).
## Oracle: Flying (This creature can't be blocked except by creatures with flying or reach.)
##         When this creature attacks or blocks, sacrifice it at end of combat.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fog Elemental", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["elemental"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying (This creature can't be blocked except by creatures with flying or reach.)\nWhen this creature attacks or blocks, sacrifice it at end of combat.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
