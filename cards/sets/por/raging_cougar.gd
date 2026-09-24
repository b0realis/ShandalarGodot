extends CardScript
## Raging Cougar — {2}{R} — Creature — Cat (Portal, 1997).
## Oracle: Haste

func build() -> CardData:
	var c := CardData.new("Raging Cougar", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["cat"])
	c.with_keywords([Mtg.Keyword.HASTE])
	c.oracle("Haste")
	return c
