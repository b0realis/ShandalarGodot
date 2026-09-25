extends CardScript
## Golden Bear — {3}{G} — Creature — Bear — 4/3 (Portal Second Age, 1998).
## Oracle: (no rules text — vanilla creature)

func build() -> CardData:
	var c := CardData.new("Golden Bear", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 3)
	c.with_subtypes(["bear"])
	c.oracle("")
	return c
