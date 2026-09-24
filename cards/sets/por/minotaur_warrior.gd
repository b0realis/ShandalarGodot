extends CardScript
## Minotaur Warrior — {2}{R} — Creature — Minotaur Warrior (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Minotaur Warrior", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["minotaur", "warrior"])
	c.oracle("")
	return c
