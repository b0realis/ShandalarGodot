extends CardScript
## Volunteer Militia — {W} — Creature — Human Soldier — 1/2 (Portal Second Age, 1998).
## Oracle: (no rules text — vanilla creature)

func build() -> CardData:
	var c := CardData.new("Volunteer Militia", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["human","soldier"])
	c.oracle("")
	return c
