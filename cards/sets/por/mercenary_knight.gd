extends CardScript
## Mercenary Knight — {2}{B} — Creature — Human Mercenary Knight (Portal, 1997).
## Oracle: When this creature enters, sacrifice it unless you discard a creature card.

func build() -> CardData:
	var c := CardData.new("Mercenary Knight", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["human", "mercenary", "knight"])
	c.oracle("When this creature enters, sacrifice it unless you discard a creature card.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
