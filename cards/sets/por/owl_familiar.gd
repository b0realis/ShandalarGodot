extends CardScript
## Owl Familiar — {1}{U} — Creature — Bird (Portal, 1997).
## Oracle: Flying
## Oracle: When this creature enters, draw a card, then discard a card.

func build() -> CardData:
	var c := CardData.new("Owl Familiar", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["bird"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, draw a card, then discard a card.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
