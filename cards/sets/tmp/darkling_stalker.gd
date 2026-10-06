extends CardScript
## Darkling Stalker — {3}{B} — Creature — Shade Spirit (common, tmp).
## Oracle: {B}: Regenerate this creature.
##         {B}: This creature gets +1/+1 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Darkling Stalker", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["shade","spirit"])
	c.oracle("{B}: Regenerate this creature.\n{B}: This creature gets +1/+1 until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
