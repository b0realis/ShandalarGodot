extends CardScript
## Goblin Piker — {1}{R} — Creature — Goblin Warrior — 2/1 (Portal Second Age, 1998).
## Oracle: (no rules text — vanilla creature)

func build() -> CardData:
	var c := CardData.new("Goblin Piker", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["goblin","warrior"])
	c.oracle("")
	return c
