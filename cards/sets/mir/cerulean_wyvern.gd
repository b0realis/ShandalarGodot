extends CardScript
## Cerulean Wyvern — {4}{U} — Creature — Drake (uncommon, mir).
## Oracle: Flying, protection from green
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cerulean Wyvern", "{4}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.with_protection_from(Mtg.ManaColor.G)
	c.oracle("Flying, protection from green")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
