extends CardScript
## Archangel — {5}{W}{W} — Creature — Angel (Portal, 1997).
## Oracle: Flying, vigilance

func build() -> CardData:
	var c := CardData.new("Archangel", "{5}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["angel"])
	c.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.VIGILANCE])
	c.oracle("Flying, vigilance")
	return c
