extends CardScript
## Barrin, Master Wizard — {1}{U}{U} — Legendary Creature — Human Wizard (rare, usg).
## Oracle: {2}, Sacrifice a permanent: Return target creature to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Barrin, Master Wizard", "{1}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("{2}, Sacrifice a permanent: Return target creature to its owner's hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
