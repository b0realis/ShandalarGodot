extends CardScript
## Eviscerator — {3}{B}{B} — Creature — Phyrexian Horror (rare, ulg).
## Oracle: Protection from white
##         When this creature enters, you lose 5 life.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Eviscerator", "{3}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["phyrexian","horror"])
	c.with_protection_from(Mtg.ManaColor.W)
	c.oracle("Protection from white\nWhen this creature enters, you lose 5 life.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
