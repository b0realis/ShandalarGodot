extends CardScript
## Llanowar Behemoth — {3}{G}{G} — Creature — Elemental (uncommon, wth).
## Oracle: Tap an untapped creature you control: This creature gets +1/+1 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Llanowar Behemoth", "{3}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["elemental"])
	c.oracle("Tap an untapped creature you control: This creature gets +1/+1 until end of turn.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
