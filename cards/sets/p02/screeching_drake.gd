extends CardScript
## Screeching Drake — {3}{U} — Creature — Drake — 2/2 (Portal Second Age, 1998).
## Oracle: Flying
## Oracle: When this creature enters, draw a card, then discard a card.

func build() -> CardData:
	var c := CardData.new("Screeching Drake", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, draw a card, then discard a card.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
