extends CardScript
## Lizard Warrior — {3}{R} — Creature — Lizard Warrior (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Lizard Warrior", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 2)
	c.with_subtypes(["lizard", "warrior"])
	c.oracle("")
	return c
