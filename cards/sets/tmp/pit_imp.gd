extends CardScript
## Pit Imp — {B} — Creature — Imp (common, tmp).
## Oracle: Flying
##         {B}: This creature gets +1/+0 until end of turn. Activate no more than twice each turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pit Imp", "{B}", Mtg.CardType.CREATURE)
	c.pt(0, 1)
	c.with_subtypes(["imp"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{B}: This creature gets +1/+0 until end of turn. Activate no more than twice each turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
