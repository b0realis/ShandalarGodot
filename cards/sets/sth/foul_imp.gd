extends CardScript
## Foul Imp — {B}{B} — Creature — Imp (common, sth).
## Oracle: Flying
##         When this creature enters, you lose 2 life.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Foul Imp", "{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["imp"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, you lose 2 life.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
