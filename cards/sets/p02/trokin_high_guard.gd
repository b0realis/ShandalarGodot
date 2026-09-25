extends CardScript
## Trokin High Guard — {3}{W} — Creature — Human Knight — 3/3 (Portal Second Age, 1998).
## Oracle: (no rules text — vanilla creature)

func build() -> CardData:
	var c := CardData.new("Trokin High Guard", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["human","knight"])
	c.oracle("")
	return c
