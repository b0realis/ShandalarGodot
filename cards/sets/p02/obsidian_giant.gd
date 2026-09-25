extends CardScript
## Obsidian Giant — {4}{R} — Creature — Giant — 4/4 (Portal Second Age, 1998).
## Oracle: (no rules text — vanilla creature)

func build() -> CardData:
	var c := CardData.new("Obsidian Giant", "{4}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["giant"])
	c.oracle("")
	return c
