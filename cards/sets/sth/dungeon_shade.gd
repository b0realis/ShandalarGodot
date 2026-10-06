extends CardScript
## Dungeon Shade — {3}{B} — Creature — Shade Spirit (common, sth).
## Oracle: Flying
##         {B}: This creature gets +1/+1 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dungeon Shade", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["shade","spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{B}: This creature gets +1/+1 until end of turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
