extends CardScript
## Foot Soldiers — {3}{W} — Creature — Human Soldier (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Foot Soldiers", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 4)
	c.with_subtypes(["human", "soldier"])
	c.oracle("")
	return c
