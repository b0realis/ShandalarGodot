extends CardScript
## Armored Griffin — {3}{W} — Creature — Griffin — 2/3 (Portal Second Age, 1998).
## Oracle: Flying, vigilance

func build() -> CardData:
	var c := CardData.new("Armored Griffin", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["griffin"])
	c.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.VIGILANCE])
	c.oracle("Flying, vigilance")
	return c
