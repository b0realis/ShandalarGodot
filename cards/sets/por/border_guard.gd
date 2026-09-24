extends CardScript
## Border Guard — {2}{W} — Creature — Human Soldier (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Border Guard", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 4)
	c.with_subtypes(["human", "soldier"])
	c.oracle("")
	return c
