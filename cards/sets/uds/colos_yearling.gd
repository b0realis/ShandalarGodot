extends CardScript
## Colos Yearling — {2}{R} — Creature — Goat Beast (common, uds).
## Oracle: Mountainwalk (This creature can't be blocked as long as defending player controls a Mountain.)
##         {R}: This creature gets +1/+0 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Colos Yearling", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["goat","beast"])
	c.with_landwalk(["mountain"])
	c.oracle("Mountainwalk (This creature can't be blocked as long as defending player controls a Mountain.)\n{R}: This creature gets +1/+0 until end of turn.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
