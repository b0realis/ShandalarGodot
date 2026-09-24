extends CardScript
## Spiritual Guardian — {3}{W}{W} — Creature — Spirit (Portal, 1997).
## Oracle: When this creature enters, you gain 4 life.

func build() -> CardData:
	var c := CardData.new("Spiritual Guardian", "{3}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["spirit"])
	c.oracle("When this creature enters, you gain 4 life.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
