extends CardScript
## Sylvan Yeti — {2}{G}{G} — Creature — Yeti — */4 (Portal Second Age, 1998).
## Oracle: Sylvan Yeti's power is equal to the number of cards in your hand.

func build() -> CardData:
	var c := CardData.new("Sylvan Yeti", "{2}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(0, 4)
	c.with_subtypes(["yeti"])
	c.oracle("Sylvan Yeti's power is equal to the number of cards in your hand.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
