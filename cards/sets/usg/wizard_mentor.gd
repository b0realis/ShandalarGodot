extends CardScript
## Wizard Mentor — {2}{U} — Creature — Human Wizard (common, usg).
## Oracle: {T}: Return this creature and target creature you control to their owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wizard Mentor", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","wizard"])
	c.oracle("{T}: Return this creature and target creature you control to their owner's hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
