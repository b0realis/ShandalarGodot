extends CardScript
## Skyshroud Vampire — {3}{B}{B} — Creature — Vampire (uncommon, tmp).
## Oracle: Flying
##         Discard a creature card: This creature gets +2/+2 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Skyshroud Vampire", "{3}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["vampire"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nDiscard a creature card: This creature gets +2/+2 until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
