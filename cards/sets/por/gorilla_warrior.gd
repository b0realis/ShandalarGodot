extends CardScript
## Gorilla Warrior — {2}{G} — Creature — Ape Warrior (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Gorilla Warrior", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["ape", "warrior"])
	c.oracle("")
	return c
