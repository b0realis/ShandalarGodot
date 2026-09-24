extends CardScript
## Serpent Assassin — {3}{B}{B} — Creature — Snake Assassin (Portal, 1997).
## Oracle: When this creature enters, you may destroy target nonblack creature.

func build() -> CardData:
	var c := CardData.new("Serpent Assassin", "{3}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["snake", "assassin"])
	c.oracle("When this creature enters, you may destroy target nonblack creature.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
