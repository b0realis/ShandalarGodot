extends CardScript
## Horned Turtle — {2}{U} — Creature — Turtle (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Horned Turtle", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 4)
	c.with_subtypes(["turtle"])
	c.oracle("")
	return c
