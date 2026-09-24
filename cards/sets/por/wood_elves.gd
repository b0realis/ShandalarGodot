extends CardScript
## Wood Elves — {2}{G} — Creature — Elf Scout (Portal, 1997).
## Oracle: When this creature enters, search your library for a Forest card, put that card onto the battlefield, then shuffle.

func build() -> CardData:
	var c := CardData.new("Wood Elves", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf", "scout"])
	c.oracle("When this creature enters, search your library for a Forest card, put that card onto the battlefield, then shuffle.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
