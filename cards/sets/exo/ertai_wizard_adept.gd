extends CardScript
## Ertai, Wizard Adept — {2}{U} — Legendary Creature — Human Wizard (rare, exo).
## Oracle: {2}{U}{U}, {T}: Counter target spell.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ertai, Wizard Adept", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("{2}{U}{U}, {T}: Counter target spell.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
