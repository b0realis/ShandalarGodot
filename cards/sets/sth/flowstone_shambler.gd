extends CardScript
## Flowstone Shambler — {2}{R} — Creature — Beast (common, sth).
## Oracle: {R}: This creature gets +1/-1 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flowstone Shambler", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["beast"])
	c.oracle("{R}: This creature gets +1/-1 until end of turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
