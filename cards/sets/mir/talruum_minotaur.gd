extends CardScript
## Talruum Minotaur — {2}{R}{R} — Creature — Minotaur Berserker (common, mir).
## Oracle: Haste
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Talruum Minotaur", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["minotaur","berserker"])
	c.with_keywords([Mtg.Keyword.HASTE])
	c.oracle("Haste")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
