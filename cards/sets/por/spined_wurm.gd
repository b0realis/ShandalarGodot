extends CardScript
## Spined Wurm — {4}{G} — Creature — Wurm (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Spined Wurm", "{4}{G}", Mtg.CardType.CREATURE)
	c.pt(5, 4)
	c.with_subtypes(["wurm"])
	c.oracle("")
	return c
