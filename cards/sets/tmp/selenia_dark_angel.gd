extends CardScript
## Selenia, Dark Angel — {3}{W}{B} — Legendary Creature — Phyrexian Angel (rare, tmp).
## Oracle: Flying
##         Pay 2 life: Return Selenia to its owner's hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Selenia, Dark Angel", "{3}{W}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["phyrexian","angel"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nPay 2 life: Return Selenia to its owner's hand.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
