extends CardScript
## Phantom Warrior — {1}{U}{U} — Creature — Illusion Warrior (Portal, 1997).
## Oracle: This creature can't be blocked.

func build() -> CardData:
	var c := CardData.new("Phantom Warrior", "{1}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["illusion", "warrior"])
	c.oracle("This creature can't be blocked.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
