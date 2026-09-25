extends CardScript
## Bear Cub — {1}{G} — Creature — Bear — 2/2 (Portal Second Age, 1998).
## Oracle: (no rules text — vanilla creature)

func build() -> CardData:
	var c := CardData.new("Bear Cub", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["bear"])
	c.oracle("")
	return c
