extends CardScript
## Plated Wurm — {4}{G} — Creature — Wurm — 4/5 (Portal Second Age, 1998).
## Oracle: (no rules text — vanilla creature)

func build() -> CardData:
	var c := CardData.new("Plated Wurm", "{4}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 5)
	c.with_subtypes(["wurm"])
	c.oracle("")
	return c
