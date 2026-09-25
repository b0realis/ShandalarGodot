extends CardScript
## Dakmor Scorpion — {1}{B} — Creature — Scorpion — 2/1 (Portal Second Age, 1998).
## Oracle: (no rules text — vanilla creature)

func build() -> CardData:
	var c := CardData.new("Dakmor Scorpion", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["scorpion"])
	c.oracle("")
	return c
