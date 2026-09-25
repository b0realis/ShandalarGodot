extends CardScript
## Alaborn Trooper — {2}{W} — Creature — Human Soldier — 2/3 (Portal Second Age, 1998).
## Oracle: (no rules text — vanilla creature)

func build() -> CardData:
	var c := CardData.new("Alaborn Trooper", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["human","soldier"])
	c.oracle("")
	return c
