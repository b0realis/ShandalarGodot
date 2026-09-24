extends CardScript
## Ebon Dragon — {5}{B}{B} — Creature — Dragon (Portal, 1997).
## Oracle: Flying
## Oracle: When this creature enters, you may have target opponent discard a card.

func build() -> CardData:
	var c := CardData.new("Ebon Dragon", "{5}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(5, 4)
	c.with_subtypes(["dragon"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, you may have target opponent discard a card.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
