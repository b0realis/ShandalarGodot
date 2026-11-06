extends CardScript
## Goblin Berserker — {3}{R} — Creature — Goblin Berserker (uncommon, uds).
## Oracle: First strike, haste
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Berserker", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["goblin","berserker"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE, Mtg.Keyword.HASTE])
	c.oracle("First strike, haste")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
