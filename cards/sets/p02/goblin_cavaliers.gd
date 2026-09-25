extends CardScript
## Goblin Cavaliers — {2}{R} — Creature — Goblin — 3/2 (Portal Second Age, 1998).
## Oracle: (no rules text — vanilla creature)

func build() -> CardData:
	var c := CardData.new("Goblin Cavaliers", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["goblin"])
	c.oracle("")
	return c
