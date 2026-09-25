extends CardScript
## Alaborn Grenadier — {W}{W} — Creature — Human Soldier — 2/2 (Portal Second Age, 1998).
## Oracle: Vigilance

func build() -> CardData:
	var c := CardData.new("Alaborn Grenadier", "{W}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","soldier"])
	c.with_keywords([Mtg.Keyword.VIGILANCE])
	c.oracle("Vigilance")
	return c
