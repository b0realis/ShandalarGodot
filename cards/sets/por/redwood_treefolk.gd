extends CardScript
## Redwood Treefolk — {4}{G} — Creature — Treefolk (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Redwood Treefolk", "{4}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 6)
	c.with_subtypes(["treefolk"])
	c.oracle("")
	return c
