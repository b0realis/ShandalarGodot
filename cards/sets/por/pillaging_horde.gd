extends CardScript
## Pillaging Horde — {2}{R}{R} — Creature — Human Barbarian (Portal, 1997).
## Oracle: When this creature enters, sacrifice it unless you discard a card at random.

func build() -> CardData:
	var c := CardData.new("Pillaging Horde", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["human", "barbarian"])
	c.oracle("When this creature enters, sacrifice it unless you discard a card at random.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
