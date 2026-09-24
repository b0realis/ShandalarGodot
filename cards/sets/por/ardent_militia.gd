extends CardScript
## Ardent Militia — {4}{W} — Creature — Human Soldier (Portal, 1997).
## Oracle: Vigilance

func build() -> CardData:
	var c := CardData.new("Ardent Militia", "{4}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 5)
	c.with_subtypes(["human", "soldier"])
	c.with_keywords([Mtg.Keyword.VIGILANCE])
	c.oracle("Vigilance")
	return c
