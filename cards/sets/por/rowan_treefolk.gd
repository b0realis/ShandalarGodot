extends CardScript
## Rowan Treefolk — {3}{G} — Creature — Treefolk (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Rowan Treefolk", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["treefolk"])
	c.oracle("")
	return c
