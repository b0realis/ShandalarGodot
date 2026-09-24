extends CardScript
## Serpent Warrior — {2}{B} — Creature — Snake Warrior (Portal, 1997).
## Oracle: When this creature enters, you lose 3 life.

func build() -> CardData:
	var c := CardData.new("Serpent Warrior", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["snake", "warrior"])
	c.oracle("When this creature enters, you lose 3 life.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
