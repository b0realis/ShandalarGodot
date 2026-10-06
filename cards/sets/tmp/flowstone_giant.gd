extends CardScript
## Flowstone Giant — {2}{R}{R} — Creature — Giant (common, tmp).
## Oracle: {R}: This creature gets +2/-2 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flowstone Giant", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["giant"])
	c.oracle("{R}: This creature gets +2/-2 until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
