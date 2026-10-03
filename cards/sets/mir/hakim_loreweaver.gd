extends CardScript
## Hakim, Loreweaver — {3}{U}{U} — Legendary Creature — Human Wizard (rare, mir).
## Oracle: Flying
##         {U}{U}: Return target Aura card from your graveyard to the battlefield attached to Hakim. Activate only during your upkeep and only if Hakim isn't enchanted.
##         {U}{U}, {T}: Destroy all Auras attached to Hakim.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hakim, Loreweaver", "{3}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 4)
	c.with_subtypes(["human","wizard"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{U}{U}: Return target Aura card from your graveyard to the battlefield attached to Hakim. Activate only during your upkeep and only if Hakim isn't enchanted.\n{U}{U}, {T}: Destroy all Auras attached to Hakim.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
