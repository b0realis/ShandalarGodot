extends CardScript
## Knight Errant — {1}{W} — Creature — Human Knight (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Knight Errant", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human", "knight"])
	c.oracle("")
	return c
