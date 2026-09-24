extends CardScript
## Goblin Bully — {1}{R} — Creature — Goblin (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Goblin Bully", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["goblin"])
	c.oracle("")
	return c
