extends CardScript
## Firefly — {3}{R} — Creature — Insect (uncommon, tmp).
## Oracle: Flying
##         {R}: This creature gets +1/+0 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Firefly", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["insect"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{R}: This creature gets +1/+0 until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
