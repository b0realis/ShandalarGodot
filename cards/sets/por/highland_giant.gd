extends CardScript
## Highland Giant — {2}{R}{R} — Creature — Giant (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Highland Giant", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["giant"])
	c.oracle("")
	return c
