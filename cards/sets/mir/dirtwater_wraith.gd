extends CardScript
## Dirtwater Wraith — {3}{B} — Creature — Wraith (common, mir).
## Oracle: Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)
##         {B}: This creature gets +1/+0 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dirtwater Wraith", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 3)
	c.with_subtypes(["wraith"])
	c.with_landwalk(["swamp"])
	c.oracle("Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)\n{B}: This creature gets +1/+0 until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
