extends CardScript
## Raging Minotaur — {2}{R}{R} — Creature — Minotaur Berserker (Portal, 1997).
## Oracle: Haste

func build() -> CardData:
	var c := CardData.new("Raging Minotaur", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["minotaur", "berserker"])
	c.with_keywords([Mtg.Keyword.HASTE])
	c.oracle("Haste")
	return c
