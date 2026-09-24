extends CardScript
## Coral Eel — {1}{U} — Creature — Fish (Portal, 1997).

func build() -> CardData:
	var c := CardData.new("Coral Eel", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["fish"])
	c.oracle("")
	return c
