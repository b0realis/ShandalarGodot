extends CardScript
## Panther Warriors — {4}{G} — Creature — Cat Warrior (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Panther Warriors", "{4}{G}", Mtg.CardType.CREATURE)
	c.pt(6, 3)
	c.with_subtypes(["cat", "warrior"])
	c.oracle("")
	return c
