extends CardScript
## Brimstone Dragon — {6}{R}{R} — Creature — Dragon — 6/6 (Portal Second Age, 1998).
## Oracle: Flying, haste

func build() -> CardData:
	var c := CardData.new("Brimstone Dragon", "{6}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(6, 6)
	c.with_subtypes(["dragon"])
	c.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.HASTE])
	c.oracle("Flying, haste")
	return c
