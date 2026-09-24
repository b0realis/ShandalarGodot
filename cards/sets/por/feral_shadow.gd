extends CardScript
## Feral Shadow — {2}{B} — Creature — Nightstalker (Portal, 1997).
## Oracle: Flying

func build() -> CardData:
	var c := CardData.new("Feral Shadow", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["nightstalker"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying")
	return c
