extends CardScript
## Barbtooth Wurm — {5}{G} — Creature — Wurm — 6/4 (Portal Second Age, 1998).
## Oracle: (no rules text — vanilla creature)

func build() -> CardData:
	var c := CardData.new("Barbtooth Wurm", "{5}{G}", Mtg.CardType.CREATURE)
	c.pt(6, 4)
	c.with_subtypes(["wurm"])
	c.oracle("")
	return c
