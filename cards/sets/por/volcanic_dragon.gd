extends CardScript
## Volcanic Dragon — {4}{R}{R} — Creature — Dragon (Portal, 1997).
## Oracle: Flying, haste

func build() -> CardData:
	var c := CardData.new("Volcanic Dragon", "{4}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["dragon"])
	c.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.HASTE])
	c.oracle("Flying, haste")
	return c
