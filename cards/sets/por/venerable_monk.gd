extends CardScript
## Venerable Monk — {2}{W} — Creature — Human Monk Cleric (Portal, 1997).
## Oracle: When this creature enters, you gain 2 life.

func build() -> CardData:
	var c := CardData.new("Venerable Monk", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human", "monk", "cleric"])
	c.oracle("When this creature enters, you gain 2 life.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
