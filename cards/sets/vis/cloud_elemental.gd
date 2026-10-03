extends CardScript
## Cloud Elemental — {2}{U} — Creature — Elemental (common, vis).
## Oracle: Flying
##         This creature can block only creatures with flying.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cloud Elemental", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["elemental"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nThis creature can block only creatures with flying.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
